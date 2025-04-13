const express = require('express');
const http = require('http');
const socketIO = require('socket.io');

const app = express();
const server = http.createServer(app);
const io = socketIO(server, {
  cors: {
    origin: '*',
    methods: ['GET', 'POST']
  }
});

// 활성 사용자를 저장할 객체
const activeUsers = {};

// 활성 통화 관리 (중복 방지용)
const activeCalls = {};

// 대기 중인 사용자 목록
let waitingUsers = [];

// 매칭 API 엔드포인트
app.get('/match', (req, res) => {
  const userId = req.query.userId;
  
  console.log(`매칭 요청: ${userId}`);
  
  if (!userId) {
    console.log('오류: 사용자 ID가 없음');
    return res.status(400).json({ error: '사용자 ID가 필요합니다' });
  }
  
  // 자기 자신을 제외한 활성 사용자 중에서 매칭
  const availableUsers = Object.keys(activeUsers).filter(id => id !== userId);
  console.log(`매칭 가능한 사용자: ${availableUsers.length ? availableUsers.join(', ') : '없음'}`);
  
  if (availableUsers.length === 0) {
    // 매칭 가능한 사용자가 없음
    waitingUsers.push(userId); // 대기 목록에 추가
    console.log(`대기 목록에 추가: ${userId}, 현재 대기 목록: ${waitingUsers.join(', ')}`);
    return res.status(404).json({ error: '현재 매칭 가능한 사용자가 없습니다' });
  }
  
  // 무작위로 사용자 선택
  const randomIndex = Math.floor(Math.random() * availableUsers.length);
  const matchedUserId = availableUsers[randomIndex];
  
  console.log(`매칭 성공: ${userId} -> ${matchedUserId}`);
  
  // 대기 목록에서 제거
  waitingUsers = waitingUsers.filter(id => id !== userId && id !== matchedUserId);
  
  return res.status(200).json({ matchedUserId });
});

io.on('connection', (socket) => {
  console.log('사용자 연결됨. 소켓 ID:', socket.id);
  
  // 사용자 등록
  socket.on('register', (userId) => {
    console.log('사용자 등록:', userId || socket.id);
    
    // userId가 없으면 socket.id 사용
    const id = userId || socket.id;
    activeUsers[id] = socket.id;
    socket.userId = id;
    
    console.log('현재 활성 사용자:', Object.keys(activeUsers));
  });
  
  // 통화 요청
  socket.on('call', (data) => {
    const { target, offer } = data;
    console.log(`통화 요청: ${socket.userId} -> ${target}`);
    
    if (activeUsers[target]) {
      io.to(activeUsers[target]).emit('incomingCall', {
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
    
    if (activeUsers[caller]) {
      console.log(`응답 전달: ${socket.userId} -> ${caller}`);
      io.to(activeUsers[caller]).emit('callAnswered', {
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
    
    if (activeUsers[target]) {
      io.to(activeUsers[target]).emit('callError', {
        sender: socket.userId,
        error
      });
    }
  });
  
  // ICE 후보 전달
  socket.on('ice-candidate', (data) => {
    const { target, candidate } = data;
    
    if (activeUsers[target]) {
      io.to(activeUsers[target]).emit('ice-candidate', {
        sender: socket.userId,
        candidate
      });
    }
  });
  
  // 통화 종료
  socket.on('endCall', (data) => {
    const { target } = data;
    
    if (activeUsers[target]) {
      io.to(activeUsers[target]).emit('callEnded', {
        caller: socket.userId
      });
    }
  });
  
  // 통화 거절 이벤트 처리
  socket.on('callRejected', (data) => {
    const { caller } = data;
    console.log(`통화 거절: ${socket.userId} -> ${caller}`);
    
    if (activeUsers[caller]) {
      io.to(activeUsers[caller]).emit('callRejected', {
        rejector: socket.userId
      });
    }
  });
  
  // 통화 수락 알림 처리
  socket.on('acceptCall', (data) => {
    const { caller, offer } = data;
    console.log(`통화 수락 알림: ${socket.userId} -> ${caller}`);
    
    // 중복 알림 방지를 위한 통화 상태 관리 추가
    if (!activeUsers[caller]) {
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
    
    io.to(activeUsers[caller]).emit('callAccepted', {
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

const PORT = process.env.PORT || 5000;
server.listen(PORT, () => {
  console.log(`서버가 포트 ${PORT}에서 실행 중입니다`);
}); 