const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
require('dotenv').config();

const app = express();

// ★★★ 반드시 라우터 등록 전에 위치해야 함!
app.use(express.json());

const server = http.createServer(app);
const io = socketIO(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// MySQL 커넥션 풀 생성
const db = mysql.createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_DATABASE,
});

// 활성 사용자를 저장할 객체
const activeUsers = {}; // { userId: { socketId, userId } }

// 활성 통화 관리 (중복 방지용)
const activeCalls = {};

// 대기 중인 사용자 목록
let waitingUsers = [];

// 프로필 이미지 저장 경로 및 파일명 지정
const storage = multer.diskStorage({
  destination: function (req, file, cb) {
    cb(null, 'C:/capstone/CapstoneDesign/assets/profile');
  },
  filename: function (req, file, cb) {
    // 닉네임으로 파일명 지정, 확장자는 png로 고정
    const nickname = req.body.nickname || 'profile';
    cb(null, `${nickname}.png`);
  }
});
const upload = multer({ storage: storage });

// 매칭 API 엔드포인트
app.get('/match', (req, res) => {
  const userId = req.query.userId;
  // userId는 반드시 숫자(문자열로 올 수 있으니 Number로 변환)
  if (!userId) {
    return res.status(400).json({ error: '사용자 ID가 필요합니다' });
  }
  // 자기 자신을 제외한 활성 사용자 중에서 매칭
  const availableUsers = Object.keys(activeUsers).filter(id => id !== userId);
  if (availableUsers.length === 0) {
    // 매칭 가능한 사용자가 없음
    waitingUsers.push(userId); // 대기 목록에 추가
    console.log(`대기 목록에 추가: ${userId}, 현재 대기 목록: ${waitingUsers.join(', ')}`);
    return res.status(404).json({ error: '현재 매칭 가능한 사용자가 없습니다' });
  }
  // 무작위로 사용자 선택
  const randomIndex = Math.floor(Math.random() * availableUsers.length);
  const matchedUserId = availableUsers[randomIndex];
  // 실제 user id(숫자) 반환
  return res.status(200).json({
    matchedUserId: Number(matchedUserId)
  });
});

io.on('connection', (socket) => {
  console.log('사용자 연결됨. 소켓 ID:', socket.id);
  
  // 사용자 등록
  socket.on('register', (userId) => {
    // userId는 반드시 숫자(실제 DB의 id)여야 함
    if (!userId) {
      console.log('userId가 없습니다. 등록 실패');
      return;
    }
    activeUsers[userId] = { socketId: socket.id, userId: userId };
    socket.userId = userId;
    console.log('현재 활성 사용자:', Object.keys(activeUsers));
  });
  
  // 통화 요청
  socket.on('call', (data) => {
    const { target, offer } = data;
    console.log(`통화 요청: ${socket.userId} -> ${target}`);
    
    if (activeUsers[target]?.socketId) {
      io.to(activeUsers[target].socketId).emit('incomingCall', {
        caller: socket.userId,
        offer
      });
    } else {
      console.log(`대상 사용자 없음: ${target}`);
    }
  });
  
  // 통화 응답
  socket.on('callAnswered', (data) => {
    const { caller, answer } = data;
    console.log(`통화 응답: ${socket.userId} -> ${caller}`);
    
    if (activeUsers[caller]?.socketId) {
      console.log(`응답 전달: ${socket.userId} -> ${caller}`);
      io.to(activeUsers[caller]?.socketId).emit('callAnswered', {
        answerer: socket.userId,
        answer
      });
    } else {
      console.log(`오류: 응답을 받을 사용자(${caller})가 활성 상태가 아님`);
      // 상대방이 없을 경우 에러 이벤트 전송
      socket.emit('callError', {
        error: '상대방이 연결되어 있지 않습니다.'
      });
    }
  });
  
  // 통화 에러 이벤트 추가
  socket.on('callError', (data) => {
    const { target, error } = data;
    console.log(`통화 에러 발생: ${socket.userId} -> ${target}, 에러: ${error}`);
    
    if (activeUsers[target]?.socketId) {
      io.to(activeUsers[target]?.socketId).emit('callError', {
        sender: socket.userId,
        error
      });
    }
  });
  
  // ICE 후보 전달
  socket.on('ice-candidate', (data) => {
    const { target, candidate } = data;
    
    if (activeUsers[target]?.socketId) {
      io.to(activeUsers[target]?.socketId).emit('ice-candidate', {
        sender: socket.userId,
        candidate
      });
    }
  });
  
  // 통화 종료
  socket.on('endCall', async (data) => {
    const { target } = data;
    const myUserId = socket.userId;
    const partnerUserId = target;

    console.log(`[endCall] from ${myUserId} to ${partnerUserId} at ${new Date().toISOString()}`);

    if (!myUserId || !partnerUserId) return;

    try {
      // 최근 3초 이내에 저장된 내역이 있으면 무시
      const [rows] = await db.query(
        `SELECT id FROM call_partners
         WHERE user_id = ? AND partner_id = ? AND updated_at > DATE_SUB(NOW(), INTERVAL 3 SECOND)`,
        [myUserId, partnerUserId]
      );
      if (rows.length === 0) {
        await db.query(
          `INSERT INTO call_partners (user_id, partner_id, count)
           VALUES (?, ?, 1)
           ON DUPLICATE KEY UPDATE count = count + 1, updated_at = NOW()`,
          [myUserId, partnerUserId]
        );
        console.log(`통화내역 저장: ${myUserId} <-> ${partnerUserId}`);
      } else {
        console.log(`중복 저장 방지: ${myUserId} <-> ${partnerUserId}`);
      }
    } catch (err) {
      console.error('통화내역 저장 오류:', err);
    }

    // 통화 종료 알림
    if (activeUsers[target]?.socketId) {
      io.to(activeUsers[target]?.socketId).emit('callEnded', {
        caller: socket.userId
      });
    }
  });
  
  // 통화 거절 이벤트 처리
  socket.on('callRejected', (data) => {
    const { caller } = data;
    console.log(`통화 거절: ${socket.userId} -> ${caller}`);
    
    if (activeUsers[caller]?.socketId) {
      io.to(activeUsers[caller]?.socketId).emit('callRejected', {
        rejector: socket.userId
      });
    }
  });
  
  // 통화 수락 알림 처리
  socket.on('acceptCall', (data) => {
    const { caller, offer } = data;
    console.log(`통화 수락 알림: ${socket.userId} -> ${caller}`);
    
    // 중복 알림 방지를 위한 통화 상태 관리 추가
    if (!activeUsers[caller]?.socketId) {
      console.log(`오류: 발신자(${caller})가 활성 상태가 아님`);
      return;
    }
    
    // 이미 처리된 요청인지 확인 (변수 추가 필요)
    const callId = `${socket.userId}-${caller}`;
    if (activeCalls[callId]) {
      console.log(`중복 수락 알림 무시: ${callId}`);
      return;
    }
    
    // 통화 상태 저장
    activeCalls[callId] = {
      caller: caller,
      receiver: socket.userId,
      timestamp: Date.now()
    };
    
    io.to(activeUsers[caller]?.socketId).emit('callAccepted', {
      acceptor: socket.userId
    });
  });
  
  // 연결 해제
  socket.on('disconnect', () => {
    if (socket.userId) {
      console.log('사용자 연결 해제:', socket.userId);
      delete activeUsers[socket.userId];
      
      // 대기 목록에서도 제거
      waitingUsers = waitingUsers.filter(id => id !== socket.userId);
    }
  });
});

// 회원가입(텍스트 정보만)
app.post('/signup', async (req, res) => {
  const { username, password, nickname, interests, gender } = req.body;
  if (!username || !password || !nickname || !gender) {
    return res.status(400).json({ error: '모든 필드를 입력해주세요.' });
  }

  try {
    // 아이디/닉네임 중복 체크
    const [userRows] = await db.query('SELECT id FROM users WHERE username = ?', [username]);
    if (userRows.length > 0) {
      return res.status(409).json({ error: '다른 id를 사용해주세요.' });
    }
    const [nickRows] = await db.query('SELECT id FROM users WHERE nickname = ?', [nickname]);
    if (nickRows.length > 0) {
      return res.status(409).json({ error: '다른 닉네임을 사용해주세요.' });
    }

    // 비밀번호 해싱
    const password_hash = await bcrypt.hash(password, 10);

    // 회원가입
    await db.query(
      'INSERT INTO users (username, password_hash, nickname, interests, gender) VALUES (?, ?, ?, ?, ?)',
      [username, password_hash, nickname, interests || null, gender]
    );

    return res.status(201).json({ message: '회원가입 성공' });
  } catch (err) {
    console.error('회원가입 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 프로필 이미지 업로드 API (id 기반으로 저장)
app.post('/upload-profile-image', upload.single('profile_image'), async (req, res) => {
  const { userId } = req.body;
  if (!userId || !req.file) {
    return res.status(400).json({ error: '유저ID와 이미지가 필요합니다.' });
  }
  const profileImagePath = `assets/profile/${userId}.png`;
  try {
    // 파일명 변경
    const fs = require('fs');
    const oldPath = req.file.path;
    const newPath = path.join(__dirname, '..', profileImagePath);
    fs.renameSync(oldPath, newPath);

    // DB에 이미지 경로 업데이트
    await db.query(
      'UPDATE users SET profile_image = ? WHERE id = ?',
      [profileImagePath, userId]
    );
    return res.status(200).json({ message: '이미지 업로드 성공', profile_image: profileImagePath });
  } catch (err) {
    console.error('프로필 이미지 업로드 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 로그인 API
app.post('/login', async (req, res) => {
  const { username, password } = req.body;
  if (!username || !password) {
    return res.status(400).json({ error: '아이디와 비밀번호를 입력해주세요.' });
  }

  try {
    const [rows] = await db.query('SELECT * FROM users WHERE username = ?', [username]);
    if (rows.length === 0) {
      return res.status(401).json({ error: '아이디 또는 비밀번호가 올바르지 않습니다.' });
    }
    const user = rows[0];
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: '아이디 또는 비밀번호가 올바르지 않습니다.' });
    }

    // JWT 토큰 발급 (user.id 포함)
    const token = jwt.sign(
      { id: user.id, username: user.username, nickname: user.nickname },
      process.env.JWT_SECRET,
      { expiresIn: '7d' }
    );

    return res.status(200).json({
      message: '로그인 성공',
      token, // 토큰 반환
      user: {
        id: user.id,
        username: user.username,
        nickname: user.nickname,
      },
    });
  } catch (err) {
    console.error('로그인 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 통화 종료 로그 API
app.post('/call-end-log', (req, res) => {
  const { myUserId, partnerUserId } = req.body;
  if (!myUserId || !partnerUserId) {
    return res.status(400).json({ error: 'user id가 필요합니다.' });
  }
  console.log(`[영상통화 종료] 내 user id: ${myUserId}, 상대방 user id: ${partnerUserId}`);
  return res.status(200).json({ message: '로그 기록 완료' });
});

// 내 통화내역 조회 API
app.get('/call-history/:userId', async (req, res) => {
  const userId = req.params.userId;
  if (!userId) {
    return res.status(400).json({ error: 'userId가 필요합니다.' });
  }
  try {
    // partner_agree를 상대방의 my_agree로 반환
    const [rows] = await db.query(
      `SELECT 
         partner_id, 
         SUM(count) as count, 
         MAX(updated_at) as updated_at, 
         MAX(step) as step, 
         MAX(my_agree) as my_agree,
         (SELECT MAX(my_agree) FROM call_partners WHERE user_id = partner_id AND partner_id = ?) as partner_agree
       FROM call_partners
       WHERE user_id = ?
       GROUP BY partner_id
       ORDER BY updated_at DESC`,
      [userId, userId]
    );
    return res.status(200).json({ partners: rows });
  } catch (err) {
    console.error('통화내역 조회 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 단계 변경 및 동의/거절 처리 API
app.post('/call-partner/step', async (req, res) => {
  const { userId, partnerId, agree, nextStep } = req.body;
  if (!userId || !partnerId || typeof agree !== 'boolean') {
    return res.status(400).json({ error: '필수 값 누락' });
  }
  try {
    if (agree) {
      // 2단계(사진 공개) → 3단계(데이트)로 진행 요청
      if (nextStep === 3) {
        // 내 row의 my_agree, 상대방 row의 partner_agree 모두 2로 변경 (데이트 동의)
        await db.query(
          `UPDATE call_partners SET my_agree = 2 WHERE user_id = ? AND partner_id = ?`,
          [userId, partnerId]
        );
        await db.query(
          `UPDATE call_partners SET partner_agree = 2 WHERE user_id = ? AND partner_id = ?`,
          [partnerId, userId]
        );
        // 둘 다 2면 step=3
        const [rows] = await db.query(
          `SELECT my_agree, partner_agree FROM call_partners WHERE user_id = ? AND partner_id = ?`,
          [userId, partnerId]
        );
        const myAgree = rows[0]?.my_agree || 0;
        const partnerAgree = rows[0]?.partner_agree || 0;
        if (myAgree === 2 && partnerAgree === 2) {
          await db.query(
            `UPDATE call_partners SET step = 3 WHERE (user_id = ? AND partner_id = ?) OR (user_id = ? AND partner_id = ?)`,
            [userId, partnerId, partnerId, userId]
          );
          return res.json({ success: true, step: 3 });
        } else {
          return res.json({ success: true, step: 2 });
        }
      }
      // 기존 2단계(사진 공개) 동의 로직은 그대로
      // 내 row의 my_agree, 상대방 row의 partner_agree 모두 1로 변경
      await db.query(
        `UPDATE call_partners SET my_agree = 1 WHERE user_id = ? AND partner_id = ?`,
        [userId, partnerId]
      );
      await db.query(
        `UPDATE call_partners SET partner_agree = 1 WHERE user_id = ? AND partner_id = ?`,
        [partnerId, userId]
      );
      // 동의 상태 확인
      const [rows] = await db.query(
        `SELECT my_agree, partner_agree FROM call_partners WHERE user_id = ? AND partner_id = ?`,
        [userId, partnerId]
      );
      const myAgree = rows[0]?.my_agree || 0;
      const partnerAgree = rows[0]?.partner_agree || 0;
      // 둘 다 동의하면 step=2로 변경
      if (myAgree && partnerAgree) {
        await db.query(
          `UPDATE call_partners SET step = 2 WHERE (user_id = ? AND partner_id = ?) OR (user_id = ? AND partner_id = ?)`,
          [userId, partnerId, partnerId, userId]
        );
        return res.json({ success: true, step: 2 });
      } else {
        return res.json({ success: true, step: 1 });
      }
    } else {
      // 거절: call_partners에서 서로 삭제
      await db.query(
        `DELETE FROM call_partners WHERE (user_id = ? AND partner_id = ?) OR (user_id = ? AND partner_id = ?)`,
        [userId, partnerId, partnerId, userId]
      );
      return res.json({ success: true, deleted: true });
    }
  } catch (err) {
    console.error('단계 변경 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 프로필 이미지 반환 API (id 기반)
app.get('/user-profile/:id', async (req, res) => {
  const userId = req.params.id;
  try {
    const [rows] = await db.query('SELECT profile_image FROM users WHERE id = ?', [userId]);
    if (rows.length === 0 || !rows[0].profile_image) {
      return res.status(404).send('이미지 없음');
    }
    // 경로 구분자 통일
    const imagePath = rows[0].profile_image.replace(/\\/g, '/');
    // 절대 경로로 변환
    const absPath = path.join(__dirname, '..', imagePath);
    return res.sendFile(absPath);
  } catch (err) {
    console.error('프로필 이미지 반환 오류:', err);
    return res.status(500).send('서버 오류');
  }
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`서버가 포트 ${PORT}에서 실행 중입니다`);
}); 