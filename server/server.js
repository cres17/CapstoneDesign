const express = require('express');
const http = require('http');
const socketIO = require('socket.io');
const mysql = require('mysql2/promise');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const multer = require('multer');
const path = require('path');
const fs = require('fs');
const crypto = require('crypto');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

if (!process.env.JWT_SECRET || process.env.JWT_SECRET.length < 32) {
  console.error('JWT_SECRET 환경변수를 32자 이상으로 설정해야 서버를 시작할 수 있습니다.');
  process.exit(1);
}

const app = express();
// 프록시 뒤에서 실행할 때만 TRUST_PROXY_HOPS를 지정한다 (요청 제한이 클라이언트 IP를 구분하도록)
if (process.env.TRUST_PROXY_HOPS) app.set('trust proxy', Number(process.env.TRUST_PROXY_HOPS));

// ★★★ 반드시 라우터 등록 전에 위치해야 함!
app.use(express.json({ limit: '1mb' }));

// 프로필 이미지 폴더: 저장소 루트의 assets/profile (DB에는 'assets/profile/<id>.png'로 저장)
const PROFILE_DIR = path.join(__dirname, '..', 'assets', 'profile');
fs.mkdirSync(PROFILE_DIR, { recursive: true });
// 프로필 사진은 관계 단계(2단계 사진 공개)에 따라 보여 주므로 정적 공개 경로를 두지 않고 /user-profile/:id에서 권한을 확인한다

// JWT 검증 미들웨어: Authorization: Bearer <token>
function requireAuth(req, res, next) {
  const header = req.headers.authorization || '';
  const token = header.startsWith('Bearer ') ? header.slice(7) : null;
  if (!token) {
    return res.status(401).json({ error: '로그인이 필요합니다.' });
  }
  try {
    req.user = verifyToken(token);
    return next();
  } catch (err) {
    return res.status(401).json({ error: '로그인이 만료되었거나 올바르지 않습니다.' });
  }
}

// 토큰 검증: 서명 알고리즘을 고정하고 숫자 id가 있는 토큰만 받는다
function verifyToken(token) {
  const payload = jwt.verify(token, process.env.JWT_SECRET, { algorithms: ['HS256'] });
  const id = Number(payload.id);
  if (!Number.isInteger(id) || id <= 0) throw new Error('invalid token subject');
  return { ...payload, id };
}

function signToken(user) {
  return jwt.sign(
    { id: user.id, username: user.username, nickname: user.nickname },
    process.env.JWT_SECRET,
    { algorithm: 'HS256', expiresIn: '7d' }
  );
}

// 요청 경로의 사용자와 토큰의 사용자가 같은지 확인
function requireSelf(req, res, next) {
  const target = req.params.id ?? req.params.userId;
  if (Number(target) !== Number(req.user?.id)) {
    return res.status(403).json({ error: '본인 정보만 조회하거나 변경할 수 있습니다.' });
  }
  return next();
}

// 두 사용자가 통화 상대(call_partners)로 이어져 있는지와 그 단계를 돌려준다. 없으면 0
async function partnerStep(userId, partnerId) {
  const [rows] = await db.query(
    'SELECT MAX(step) AS step FROM call_partners WHERE user_id = ? AND partner_id = ?',
    [userId, partnerId]
  );
  return Number(rows[0]?.step || 0);
}

async function isRoomMember(roomId, userId) {
  const [rows] = await db.query(
    'SELECT id FROM chat_rooms WHERE id = ? AND (user1_id = ? OR user2_id = ?)',
    [roomId, userId, userId]
  );
  return rows.length > 0;
}

// 실제로 연결된 통화만 통화 기록으로 남기기 위해, 수락된 통화 쌍을 일정 시간 기억한다
const RECENT_CALL_MS = 3 * 60 * 60 * 1000;
const recentCalls = new Map(); // 'smallId-largeId' -> timestamp
function callKey(a, b) {
  const [x, y] = [Number(a), Number(b)].sort((m, n) => m - n);
  return `${x}-${y}`;
}
function rememberCall(a, b) {
  recentCalls.set(callKey(a, b), Date.now());
}
function hadRecentCall(a, b) {
  const at = recentCalls.get(callKey(a, b));
  return Boolean(at && Date.now() - at < RECENT_CALL_MS);
}

const authLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
});
const uploadLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 30,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
});

const server = http.createServer(app);
// 모바일 앱은 Origin을 보내지 않으므로 기본값은 브라우저 교차 출처 접속을 허용하지 않는다.
// 웹 클라이언트가 필요하면 SOCKET_CORS_ORIGINS에 쉼표로 출처를 적는다.
const socketOrigins = (process.env.SOCKET_CORS_ORIGINS || '')
  .split(',').map((o) => o.trim()).filter(Boolean);
const io = socketIO(server, {
  cors: socketOrigins.length ? { origin: socketOrigins, methods: ['GET', 'POST'] } : undefined,
  maxHttpBufferSize: 1e6,
});

// 소켓 연결 시 JWT를 확인하고, 이후 모든 이벤트의 사용자 id는 토큰에서만 가져온다
io.use((socket, next) => {
  const token = socket.handshake.auth?.token;
  if (!token) return next(new Error('unauthorized'));
  try {
    socket.data.user = verifyToken(token);
    return next();
  } catch (err) {
    return next(new Error('unauthorized'));
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
    cb(null, PROFILE_DIR);
  },
  filename: function (req, file, cb) {
    // 임시 이름으로 저장한 뒤 업로드 처리에서 <id>.png로 바꾼다
    cb(null, `upload-${Date.now()}-${crypto.randomBytes(8).toString('hex')}.tmp`);
  }
});
const upload = multer({
  storage: storage,
  limits: { fileSize: 5 * 1024 * 1024, files: 1, fields: 5 },
  fileFilter: function (req, file, cb) {
    cb(null, ['image/png', 'image/jpeg', 'image/webp'].includes(file.mimetype));
  },
});

// 매칭 API 엔드포인트
app.get('/match', requireAuth, (req, res) => {
  const userId = String(req.user.id);
  // 자기 자신을 제외한 활성 사용자 중에서 매칭
  const availableUsers = Object.keys(activeUsers).filter(id => id !== userId);
  if (availableUsers.length === 0) {
    // ★★★ 이미 대기목록에 없을 때만 추가
    if (!waitingUsers.includes(userId)) {
      waitingUsers.push(userId);
      console.log(`대기 목록에 추가: ${userId}, 현재 대기 목록: ${waitingUsers.join(', ')}`);
    } else {
      console.log(`이미 대기 목록에 있음: ${userId}, 현재 대기 목록: ${waitingUsers.join(', ')}`);
    }
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
  // 연결 시 검증한 토큰의 사용자 id. 이후 이벤트는 이 값만 신뢰한다
  socket.userId = String(socket.data.user.id);
  
  // 사용자 등록
  socket.on('register', () => {
    // 클라이언트가 보낸 id는 쓰지 않고, 연결 시 검증한 토큰의 id로 등록한다
    const userId = String(socket.data.user.id);
    activeUsers[userId] = { socketId: socket.id, userId: userId };
    socket.userId = userId;
    console.log('현재 활성 사용자:', Object.keys(activeUsers));
  });
  
  // 통화 요청
  socket.on('call', (data) => {
    const { callee } = data || {};
    const caller = socket.userId;
    if (!caller || !callee) {
      console.log(`[call] 잘못된 요청: caller=${caller}, callee=${callee}, socket: ${socket.id}`);
      return;
    }
    console.log(`[call] from: ${caller} to: ${callee}, socket: ${socket.id}`);
    console.log(`통화 요청: ${socket.userId} -> ${callee}`);
    
    if (activeUsers[callee]?.socketId) {
      io.to(activeUsers[callee].socketId).emit('incomingCall', {
        caller: socket.userId,
        offer: data.offer
      });
    } else {
      console.log(`대상 사용자 없음: ${callee}`);
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
    if (!hadRecentCall(myUserId, partnerUserId)) return;

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
    rememberCall(socket.userId, caller);
    
    io.to(activeUsers[caller]?.socketId).emit('callAccepted', {
      acceptor: socket.userId
    });
  });
  
  // 소켓 이벤트 등록
  socket.on('leaveWaiting', () => {
    const userId = socket.userId;
    waitingUsers = waitingUsers.filter(id => id !== userId);
    console.log('대기 목록에서 제거:', userId, waitingUsers);
  });

  // 소켓 연결 해제 시에도 자동으로 제거
  socket.on('disconnect', () => {
    console.log(`[disconnect] socket: ${socket.id}`);
    if (socket.userId) {
      waitingUsers = waitingUsers.filter(id => id !== socket.userId);
      // 같은 사용자가 새 소켓으로 다시 등록한 경우는 지우지 않는다
      if (activeUsers[socket.userId]?.socketId === socket.id) {
        delete activeUsers[socket.userId];
      }
    }
  });

  // 채팅방 입장
  socket.on('joinRoom', async (roomId) => {
    const id = parseInt(roomId, 10);
    if (!id) return;
    try {
      if (!(await isRoomMember(id, socket.data.user.id))) {
        socket.emit('messageError', { roomId: id, error: '채팅방에 참여할 수 없습니다.' });
        return;
      }
      socket.join(`room_${id}`);
    } catch (err) {
      console.error('채팅방 입장 확인 오류:', err);
    }
  });

  // 메시지 전송
  socket.on('sendMessage', async (data) => {
    // data: { roomId, senderId, message }
    const roomId = parseInt(data?.roomId, 10);
    const message = data?.message;
    const senderId = socket.data.user.id;
    if (!roomId || typeof message !== 'string' || message.trim() === '' || message.length > 2000) {
      return;
    }
    if (!socket.rooms.has(`room_${roomId}`)) {
      socket.emit('messageError', { roomId, error: '채팅방에 먼저 입장해야 합니다.' });
      return;
    }
    // DB 저장 (실패해도 서버 프로세스가 종료되지 않도록 처리)
    try {
      await db.query(
        `INSERT INTO chat_messages (room_id, sender_id, message) VALUES (?, ?, ?)`,
        [roomId, senderId, message]
      );
    } catch (err) {
      console.error('채팅 메시지 저장 오류:', err);
      socket.emit('messageError', { roomId, error: '메시지를 저장하지 못했습니다.' });
      return;
    }
    // 실시간 전파
    io.to(`room_${roomId}`).emit('receiveMessage', {
      roomId,
      senderId,
      message,
      created_at: new Date().toISOString(),
    });
  });

  socket.on('answer', (data) => {
    console.log(`[answer] from: ${data.callee} to: ${data.caller}, socket: ${socket.id}`);
    // ... 기존 answer 처리 ...
  });
});

// 회원가입(텍스트 정보만)
app.post('/signup', authLimiter, async (req, res) => {
  const { username, password, nickname, interests, gender, latitude, longitude } = req.body || {};
  if (!username || !password || !nickname || !gender) {
    return res.status(400).json({ error: '모든 필드를 입력해주세요.' });
  }
  if (typeof username !== 'string' || typeof password !== 'string' || typeof nickname !== 'string' ||
      username.length > 50 || nickname.length > 30 || password.length < 8 || password.length > 72) {
    return res.status(400).json({ error: '아이디는 50자, 닉네임은 30자 이하, 비밀번호는 8~72자로 입력해주세요.' });
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
    const [result] = await db.query(
      'INSERT INTO users (username, password_hash, nickname, interests, gender, latitude, longitude) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [username, password_hash, nickname, interests || null, gender, latitude, longitude]
    );

    // 가입 직후 프로필 사진을 본인 계정으로만 올릴 수 있도록 토큰을 함께 발급한다
    const user = { id: result.insertId, username, nickname, gender };
    return res.status(201).json({ message: '회원가입 성공', token: signToken(user), user });
  } catch (err) {
    console.error('회원가입 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 프로필 이미지 업로드 API (id 기반으로 저장)
app.post('/upload-profile-image', uploadLimiter, requireAuth, upload.single('profile_image'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'PNG · JPEG · WebP 이미지(5MB 이하)를 올려주세요.' });
    }
    const oldPath = req.file.path;
    // 파일 내용의 시그니처로 실제 이미지인지 다시 확인한다 (MIME 헤더는 클라이언트가 정한다)
    const head = Buffer.alloc(12);
    const fd = fs.openSync(oldPath, 'r');
    fs.readSync(fd, head, 0, 12, 0);
    fs.closeSync(fd);
    const isPng = head.subarray(0, 8).equals(Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]));
    const isJpeg = head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff;
    const isWebp = head.subarray(0, 4).toString('latin1') === 'RIFF' && head.subarray(8, 12).toString('latin1') === 'WEBP';
    if (!isPng && !isJpeg && !isWebp) {
      fs.rmSync(oldPath, { force: true });
      return res.status(400).json({ error: '이미지 파일만 올릴 수 있습니다.' });
    }
    const userId = req.user.id;

    // 3. id.png로 파일명 변경
    const newPath = path.join(req.file.destination, `${userId}.png`);
    fs.renameSync(oldPath, newPath);

    const profileImagePath = `assets/profile/${userId}.png`;

    // 4. DB에 이미지 경로 업데이트 (id 기준)
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
app.post('/login', authLimiter, async (req, res) => {
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
    if (typeof password !== 'string') {
      return res.status(400).json({ error: '아이디와 비밀번호를 입력해주세요.' });
    }
    const isMatch = await bcrypt.compare(password, user.password_hash);
    if (!isMatch) {
      return res.status(401).json({ error: '아이디 또는 비밀번호가 올바르지 않습니다.' });
    }

    // JWT 토큰 발급 (user.id 포함)
    const token = signToken(user);

    return res.status(200).json({
      message: '로그인 성공',
      token, // 토큰 반환
      user: {
        id: user.id,
        username: user.username,
        nickname: user.nickname,
        gender: user.gender,
      },
    });
  } catch (err) {
    console.error('로그인 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 통화 종료 로그 API
app.post('/call-end-log', requireAuth, (req, res) => {
  const { myUserId, partnerUserId } = req.body;
  if (!myUserId || !partnerUserId) {
    return res.status(400).json({ error: 'user id가 필요합니다.' });
  }
  console.log(`[영상통화 종료] 내 user id: ${myUserId}, 상대방 user id: ${partnerUserId}`);
  return res.status(200).json({ message: '로그 기록 완료' });
});

// 내 통화내역 조회 API
app.get('/call-history/:userId', requireAuth, requireSelf, async (req, res) => {
  const userId = req.user.id;
  if (!userId) {
    return res.status(400).json({ error: 'userId가 필요합니다.' });
  }
  try {
    const [rows] = await db.query(
      `SELECT 
         partner_id, 
         SUM(count) as count, 
         MAX(updated_at) as updated_at, 
         MAX(step) as step, 
         MAX(my_agree) as my_agree,
         (SELECT MAX(my_agree) FROM call_partners WHERE user_id = partner_id AND partner_id = user_id) as partner_agree
       FROM call_partners
       WHERE user_id = ?
       GROUP BY partner_id
       ORDER BY updated_at DESC`,
      [userId]
    );
    return res.status(200).json({ partners: rows });
  } catch (err) {
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 단계 변경 및 동의/거절 처리 API
app.post('/call-partner/step', requireAuth, async (req, res) => {
  let { partnerId, agree, nextStep } = req.body || {};
  // 요청 본문의 user_id 대신 토큰의 사용자로만 동의·거절을 처리한다
  const user_id = req.user.id;
  partnerId = parseInt(partnerId, 10);
  nextStep = Number(nextStep);

  if (!user_id || !partnerId || agree === undefined || !nextStep) {
    return res.status(400).json({ error: '필수 값 누락' });
  }
  if (nextStep !== 2 && nextStep !== 3) {
    return res.status(400).json({ error: '단계 값이 올바르지 않습니다.' });
  }
  try {
    if ((await partnerStep(user_id, partnerId)) === 0) {
      return res.status(404).json({ error: '통화한 상대가 아닙니다.' });
    }
    // 0. 거절하면 두 사람의 통화 상대 기록을 모두 삭제 (README: 거절하면 상대 목록에서 삭제)
    if (agree === false || agree === 'false') {
      await db.query(
        'DELETE FROM call_partners WHERE (user_id = ? AND partner_id = ?) OR (user_id = ? AND partner_id = ?)',
        [user_id, partnerId, partnerId, user_id]
      );
      return res.json({ success: true, rejected: true });
    }

    // 1. 내 row 업데이트 (my_agree)
    await db.query(
      'UPDATE call_partners SET my_agree = ? WHERE user_id = ? AND partner_id = ?',
      [nextStep === 3 ? 2 : 1, user_id, partnerId]
    );
    // 2. 상대 row 업데이트 (partner_agree)
    await db.query(
      'UPDATE call_partners SET partner_agree = ? WHERE user_id = ? AND partner_id = ?',
      [nextStep === 3 ? 2 : 1, partnerId, user_id]
    );

    // 3. 동의 상태 확인
    const [rows] = await db.query(
      'SELECT my_agree, partner_agree, step FROM call_partners WHERE user_id = ? AND partner_id = ?',
      [user_id, partnerId]
    );
    const myAgree = rows[0]?.my_agree || 0;
    const partnerAgree = rows[0]?.partner_agree || 0;
    let step = rows[0]?.step || 1;

    // 4. 두 명 모두 동의해야만 단계가 올라감
    if (step === 1 && myAgree === 1 && partnerAgree === 1) {
      // 2단계(사진 공개)로
      await db.query(
        'UPDATE call_partners SET step = 2 WHERE (user_id = ? AND partner_id = ?) OR (user_id = ? AND partner_id = ?)',
        [user_id, partnerId, partnerId, user_id]
      );
      step = 2;
    }
    if (step === 2 && myAgree === 2 && partnerAgree === 2) {
      // 3단계(데이트)로
      await db.query(
        'UPDATE call_partners SET step = 3 WHERE (user_id = ? AND partner_id = ?) OR (user_id = ? AND partner_id = ?)',
        [user_id, partnerId, partnerId, user_id]
      );
      step = 3;

      // ★★★ 3단계 진입 시 채팅방 자동 생성 (중복 방지)
      const [chatRooms] = await db.query(
        'SELECT id FROM chat_rooms WHERE (user1_id = ? AND user2_id = ?) OR (user1_id = ? AND user2_id = ?)',
        [user_id, partnerId, partnerId, user_id]
      );
      if (chatRooms.length === 0) {
        await db.query(
          'INSERT INTO chat_rooms (user1_id, user2_id) VALUES (?, ?)',
          [user_id, partnerId]
        );
      }
    }

    return res.json({ success: true, step });
  } catch (err) {
    return res.status(500).json({ error: 'DB 오류' });
  }
});

// 프로필 이미지 반환 API (id 기반)
app.get('/user-profile/:id', requireAuth, async (req, res) => {
  const userId = parseInt(req.params.id, 10);
  if (!userId) return res.status(400).send('잘못된 요청');
  try {
    // 본인 사진이거나, 두 사람 모두 동의해 2단계(사진 공개) 이상인 상대의 사진만 보여 준다
    if (userId !== req.user.id && (await partnerStep(req.user.id, userId)) < 2) {
      return res.status(403).send('사진 공개 전입니다');
    }
    const [rows] = await db.query('SELECT profile_image FROM users WHERE id = ?', [userId]);
    if (rows.length === 0 || !rows[0].profile_image) {
      return res.status(404).send('이미지 없음');
    }
    // 경로 구분자 통일
    // DB 값과 관계없이 프로필 폴더 안의 <id>.png만 보낸다
    const absPath = path.join(PROFILE_DIR, `${userId}.png`);
    res.set('Cache-Control', 'private, no-store');
    return res.sendFile(absPath, (err) => {
      if (err && !res.headersSent) res.status(404).send('이미지 없음');
    });
  } catch (err) {
    console.error('프로필 이미지 반환 오류:', err);
    return res.status(500).send('서버 오류');
  }
});

// 내 채팅방 목록 조회 API
app.get('/chat-rooms/:userId', requireAuth, requireSelf, async (req, res) => {
  const userId = req.user.id;
  console.log(`[채팅방 목록] 요청 userId: ${userId}`);
  if (!userId) return res.status(400).json({ error: 'userId 필요' });
  try {
    const [rows] = await db.query(
      `SELECT id, user1_id, user2_id, created_at
       FROM chat_rooms
       WHERE user1_id = ? OR user2_id = ?
       ORDER BY created_at DESC`,
      [userId, userId]
    );
    res.json({ rooms: rows });
  } catch (err) {
    console.error('채팅방 목록 오류:', err);
    res.status(500).json({ error: '서버 오류' });
  }
});

// 채팅방 메시지 목록 조회
app.get('/chat-messages/:roomId', requireAuth, async (req, res) => {
  const roomId = parseInt(req.params.roomId, 10);
  if (!roomId) return res.status(400).json({ error: 'roomId 필요' });
  try {
    if (!(await isRoomMember(roomId, req.user.id))) {
      return res.status(403).json({ error: '참여한 채팅방만 볼 수 있습니다.' });
    }
    const [rows] = await db.query(
      `SELECT id, sender_id, message, created_at
       FROM chat_messages
       WHERE room_id = ?
       ORDER BY created_at ASC`,
      [roomId]
    );
    res.json({ messages: rows });
  } catch (err) {
    console.error('채팅 메시지 목록 오류:', err);
    res.status(500).json({ error: '서버 오류' });
  }
});

// 3단계(데이트)까지 간 상대방 목록 + 위치 반환 API
app.get('/date-partners/:userId', requireAuth, requireSelf, async (req, res) => {
  const userId = req.user.id;
  if (!userId) {
    return res.status(400).json({ error: 'userId가 필요합니다.' });
  }
  try {
    console.log('데이트 파트너 조회 요청 userId:', userId);
    const [rows] = await db.query(
      `SELECT 
         cp.partner_id, 
         u.nickname, 
         u.profile_image, 
         u.latitude, 
         u.longitude
       FROM call_partners cp
       JOIN users u ON cp.partner_id = u.id
       WHERE cp.user_id = ? AND cp.step = 3`,
      [userId]
    );
    return res.status(200).json({ partners: rows });
  } catch (err) {
    console.error('데이트 파트너 조회 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 통화내역 저장 (DB)
app.post('/api/call-history', requireAuth, async (req, res) => {
  const user_id = req.user.id;
  const partner_id = parseInt(req.body?.partner_id, 10);
  const date = new Date(req.body?.date);
  if (!partner_id || Number.isNaN(date.getTime())) {
    return res.status(400).json({ error: '필수 값 누락' });
  }
  // 서버가 중계한 통화가 실제로 수락된 상대만 기록한다
  if (!hadRecentCall(user_id, partner_id)) {
    return res.status(403).json({ error: '최근 통화한 상대가 아닙니다.' });
  }
  try {
    // 1. (user_id, partner_id) 저장 또는 갱신
    const [rows1] = await db.query(
      'SELECT * FROM call_partners WHERE user_id = ? AND partner_id = ?',
      [user_id, partner_id]
    );
    if (rows1.length > 0) {
      await db.query(
        'UPDATE call_partners SET count = count + 1, updated_at = ?, step = 1 WHERE user_id = ? AND partner_id = ?',
        [date, user_id, partner_id]
      );
    } else {
      await db.query(
        'INSERT INTO call_partners (user_id, partner_id, updated_at, count, step) VALUES (?, ?, ?, 1, 1)',
        [user_id, partner_id, date]
      );
    }

    // 2. (partner_id, user_id)도 저장 또는 갱신 (반대 방향)
    const [rows2] = await db.query(
      'SELECT * FROM call_partners WHERE user_id = ? AND partner_id = ?',
      [partner_id, user_id]
    );
    if (rows2.length > 0) {
      await db.query(
        'UPDATE call_partners SET count = count + 1, updated_at = ?, step = 1 WHERE user_id = ? AND partner_id = ?',
        [date, partner_id, user_id]
      );
    } else {
      await db.query(
        'INSERT INTO call_partners (user_id, partner_id, updated_at, count, step) VALUES (?, ?, ?, 1, 1)',
        [partner_id, user_id, date]
      );
    }

    return res.json({ success: true });
  } catch (err) {
    console.error('통화내역 DB 저장 오류:', err);
    return res.status(500).json({ error: 'DB 저장 오류' });
  }
});

// 유저 정보 조회 (닉네임 포함)
app.get('/users/:userId', requireAuth, async (req, res) => {
  const userId = req.params.userId;
  try {
    const [rows] = await db.query('SELECT id, nickname FROM users WHERE id = ?', [userId]);
    if (rows.length === 0) {
      return res.status(404).json({ error: '유저를 찾을 수 없습니다.' });
    }
    return res.json(rows[0]);
  } catch (err) {
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 주소(위치) 갱신: 장소 추천에 쓰는 내 좌표를 현재 위치로 바꾼다
app.put('/users/:id/location', requireAuth, requireSelf, async (req, res) => {
  const latitude = Number(req.body.latitude);
  const longitude = Number(req.body.longitude);
  if (!Number.isFinite(latitude) || !Number.isFinite(longitude) ||
      Math.abs(latitude) > 90 || Math.abs(longitude) > 180) {
    return res.status(400).json({ error: '올바른 위치가 아닙니다.' });
  }
  try {
    await db.query('UPDATE users SET latitude = ?, longitude = ? WHERE id = ?',
      [latitude, longitude, req.user.id]);
    return res.json({ success: true, latitude, longitude });
  } catch (err) {
    console.error('위치 갱신 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  }
});

// 회원탈퇴: 계정과 통화 상대·채팅 기록, 프로필 이미지를 함께 삭제
app.delete('/users/:id', requireAuth, requireSelf, async (req, res) => {
  const userId = req.user.id;
  const conn = await db.getConnection();
  try {
    await conn.beginTransaction();
    const [rooms] = await conn.query(
      'SELECT id FROM chat_rooms WHERE user1_id = ? OR user2_id = ?', [userId, userId]);
    const roomIds = rooms.map((r) => r.id);
    if (roomIds.length > 0) {
      await conn.query('DELETE FROM chat_messages WHERE room_id IN (?)', [roomIds]);
      await conn.query('DELETE FROM chat_rooms WHERE id IN (?)', [roomIds]);
    }
    await conn.query('DELETE FROM call_partners WHERE user_id = ? OR partner_id = ?', [userId, userId]);
    const [result] = await conn.query('DELETE FROM users WHERE id = ?', [userId]);
    await conn.commit();
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: '유저를 찾을 수 없습니다.' });
    }
    fs.rmSync(path.join(PROFILE_DIR, `${userId}.png`), { force: true });
    return res.json({ success: true });
  } catch (err) {
    await conn.rollback();
    console.error('회원탈퇴 오류:', err);
    return res.status(500).json({ error: '서버 오류' });
  } finally {
    conn.release();
  }
});

// ── 외부 AI API 중계 ─────────────────────────────────────────────────────────
// OpenAI · CLOVA Speech 키와 모델 서버 주소는 서버 환경변수에만 두고, 앱에는 넣지 않는다.
const aiLimiter = rateLimit({
  windowMs: 60 * 60 * 1000,
  limit: 60,
  standardHeaders: 'draft-7',
  legacyHeaders: false,
  message: { error: '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.' },
});
const audioUpload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 30 * 1024 * 1024, files: 1, fields: 2 },
});

const ANALYSIS_PROMPT = `너는 대화 분석 전문가이자 화용언어학자야. 아래 대화는 발화자 A와 B가 참여한 실제 대화야.

이 대화를 다음 세 가지 기준에 따라 분석해줘.

1. 적절한 주제 탐색 (협력의 원리, 상호 호혜적 의사소통의 원리)
2. 자아 노출의 적정성 유지 (거리유지의 원칙)
3. 경청과 협력적 반응 (협력의 원리, 공손성의 원리)

각 항목마다 발화자 A와 B의 발화를 평가해줘.
각 항목에서 “잘 드러난 부분”과 “아쉬운 부분”을 구체적 발화 예시를 포함하여 JSON 형식으로만 응답해줘.
설명 없이 아래의 JSON 포맷을 그대로 따라줘.

{
  "주제탐색": {
    "A": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    },
    "B": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    }
  },
  "자아노출": {
    "A": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    },
    "B": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    }
  },
  "경청협력": {
    "A": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    },
    "B": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    }
  }
}

대화:
`;

// 통화 녹음 → CLOVA Speech STT. 응답 본문은 CLOVA 응답을 그대로 돌려준다
app.post('/api/stt', aiLimiter, requireAuth, audioUpload.single('media'), async (req, res) => {
  const secret = process.env.CLOVA_SPEECH_SECRET;
  const url = process.env.CLOVA_SPEECH_URL;
  if (!secret || !url) return res.status(503).json({ error: 'STT 설정이 없습니다.' });
  if (!req.file || req.file.size === 0) return res.status(400).json({ error: '녹음 파일이 없습니다.' });
  try {
    const form = new FormData();
    form.append('media', new Blob([req.file.buffer], { type: 'audio/aac' }), 'call_record.aac');
    form.append('params', JSON.stringify({ language: 'ko-KR', completion: 'sync', callback: '', fullText: true }));
    form.append('type', 'application/json');
    const upstream = await fetch(url, {
      method: 'POST',
      headers: { 'X-CLOVASPEECH-API-KEY': secret, Accept: 'application/json' },
      body: form,
      signal: AbortSignal.timeout(120000),
    });
    const text = await upstream.text();
    return res.status(upstream.ok ? 200 : 502).type('application/json').send(text);
  } catch (err) {
    console.error('STT 중계 오류:', err);
    return res.status(502).json({ error: 'STT 요청에 실패했습니다.' });
  }
});

// 대화문 → OpenAI 대화 분석. 응답 본문은 OpenAI Chat Completions 응답을 그대로 돌려준다
app.post('/api/analysis', aiLimiter, requireAuth, async (req, res) => {
  const key = process.env.OPENAI_API_KEY;
  if (!key) return res.status(503).json({ error: '대화 분석 설정이 없습니다.' });
  const conversation = req.body?.conversation;
  if (typeof conversation !== 'string' || !conversation.trim() || conversation.length > 50000) {
    return res.status(400).json({ error: '대화 내용이 올바르지 않습니다.' });
  }
  try {
    const upstream = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${key}` },
      body: JSON.stringify({
        model: process.env.OPENAI_MODEL || 'gpt-4.1-nano-2025-04-14',
        messages: [{ role: 'user', content: ANALYSIS_PROMPT + conversation }],
      }),
      signal: AbortSignal.timeout(60000),
    });
    const text = await upstream.text();
    return res.status(upstream.ok ? 200 : 502).type('application/json').send(text);
  } catch (err) {
    console.error('대화 분석 중계 오류:', err);
    return res.status(502).json({ error: '대화 분석 요청에 실패했습니다.' });
  }
});

// 대화문 → 호감도 모델 서버(model_server.py). 모델 서버는 이 서버에서만 접근하도록 내부 주소에 둔다
app.post('/api/predict', aiLimiter, requireAuth, async (req, res) => {
  const inputText = req.body?.input_text;
  const gender = req.body?.gender;
  if (typeof inputText !== 'string' || !inputText.trim() || inputText.length > 50000 ||
      !['male', 'female'].includes(gender)) {
    return res.status(400).json({ error: 'input_text와 gender(male/female)가 필요합니다.' });
  }
  try {
    const upstream = await fetch(process.env.MODEL_SERVER_URL || 'http://127.0.0.1:5001/analyze', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ input_text: inputText, gender }),
      signal: AbortSignal.timeout(60000),
    });
    const text = await upstream.text();
    return res.status(upstream.ok ? 200 : 502).type('application/json').send(text);
  } catch (err) {
    console.error('호감도 예측 중계 오류:', err);
    return res.status(502).json({ error: '호감도 예측 요청에 실패했습니다.' });
  }
});

// 위치 기반 데이트 장소(TourAPI locationBasedList1). 서비스 키는 서버에만 둔다. 응답은 TourAPI XML 그대로
app.get('/api/date-spots', aiLimiter, requireAuth, async (req, res) => {
  const key = process.env.TOUR_API_KEY;
  if (!key) return res.status(503).json({ error: '장소 추천 설정이 없습니다.' });
  const lat = Number(req.query.lat);
  const lng = Number(req.query.lng);
  const rows = Math.min(Math.max(parseInt(req.query.rows, 10) || 10, 1), 30);
  if (!Number.isFinite(lat) || !Number.isFinite(lng) || Math.abs(lat) > 90 || Math.abs(lng) > 180) {
    return res.status(400).json({ error: '위치가 올바르지 않습니다.' });
  }
  const url = new URL('https://apis.data.go.kr/B551011/KorService1/locationBasedList1');
  url.search = new URLSearchParams({
    MobileOS: 'AND', MobileApp: 'daon', mapX: String(lng), mapY: String(lat), radius: '5000',
    contentTypeId: '39', serviceKey: key, _type: 'xml', numOfRows: String(rows),
  }).toString();
  try {
    const upstream = await fetch(url, { signal: AbortSignal.timeout(15000) });
    const text = await upstream.text();
    return res.status(upstream.ok ? 200 : 502).type('application/xml').send(text);
  } catch (err) {
    console.error('장소 추천 중계 오류:', err);
    return res.status(502).json({ error: '장소 추천 요청에 실패했습니다.' });
  }
});

// multer 제한 초과 등 업로드 오류를 JSON으로 돌려준다
app.use((err, req, res, next) => {
  if (err instanceof multer.MulterError) {
    return res.status(400).json({ error: '파일 크기 또는 형식이 허용 범위를 벗어났습니다.' });
  }
  console.error('요청 처리 오류:', err);
  return res.status(500).json({ error: '서버 오류' });
});

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`서버가 포트 ${PORT}에서 실행 중입니다`);
}); 