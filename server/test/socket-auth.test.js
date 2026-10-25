// Socket.IO 인증·채팅방 참여자 검증·발신자 위조 방지 회귀검사
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const h = require('./helpers');

let conn;
let srv;
let alice; let bob; let carol;
let roomAB;
const sockets = [];

async function connect(id) {
  const s = await h.connectSocket(srv.baseUrl, h.tokenFor(id));
  sockets.push(s);
  return s;
}

before(async () => {
  conn = await h.connectDb();
  await h.resetDb(conn);
  alice = await h.createUser(conn, 'alice', '여성');
  bob = await h.createUser(conn, 'bob', '남성');
  carol = await h.createUser(conn, 'carol', '여성');
  const [room] = await conn.query('INSERT INTO chat_rooms (user1_id, user2_id) VALUES (?, ?)', [alice, bob]);
  roomAB = room.insertId;
  srv = await h.startServer(5102);
});

after(async () => {
  for (const s of sockets) s.close();
  await h.stopServer(srv);
  await conn.end();
});

test('토큰 없이 또는 잘못된 토큰으로는 소켓 연결이 거부된다', async () => {
  await assert.rejects(h.connectSocket(srv.baseUrl, undefined), /unauthorized/);
  await assert.rejects(h.connectSocket(srv.baseUrl, 'not-a-jwt'), /unauthorized/);
  await assert.rejects(
    h.connectSocket(srv.baseUrl, h.tokenFor(alice, 'another-secret-0123456789abcdef0123456789')),
    /unauthorized/
  );
});

test('참여하지 않은 채팅방에는 입장할 수 없고 메시지도 저장되지 않는다', async () => {
  const c = await connect(carol);
  const errP = h.waitFor(c, 'messageError');
  c.emit('joinRoom', roomAB);
  const err = await errP;
  assert.ok(err, 'messageError를 받아야 한다');
  assert.equal(err.roomId, roomAB);

  const err2P = h.waitFor(c, 'messageError');
  c.emit('sendMessage', { roomId: roomAB, senderId: alice, message: '끼어들기' });
  assert.ok(await err2P);

  await h.sleep(200);
  const [rows] = await conn.query('SELECT id FROM chat_messages WHERE room_id = ?', [roomAB]);
  assert.equal(rows.length, 0);
});

test('입장하지 않은 방에 바로 메시지를 보내면 거부된다', async () => {
  const a = await connect(alice);
  const errP = h.waitFor(a, 'messageError');
  a.emit('sendMessage', { roomId: roomAB, message: '입장 전' });
  assert.ok(await errP);
  const [rows] = await conn.query('SELECT id FROM chat_messages WHERE room_id = ?', [roomAB]);
  assert.equal(rows.length, 0);
});

test('senderId를 위조해도 저장·전파되는 발신자는 토큰 사용자다', async () => {
  const a = await connect(alice);
  const b = await connect(bob);
  a.emit('joinRoom', roomAB);
  b.emit('joinRoom', roomAB);
  await h.sleep(200);

  const receivedP = h.waitFor(b, 'receiveMessage');
  // bob 소켓이 alice 명의로 보내려 한다
  b.emit('sendMessage', { roomId: roomAB, senderId: alice, message: '위조 시도' });
  const received = await receivedP;
  assert.ok(received);
  assert.equal(received.senderId, bob);

  const [rows] = await conn.query('SELECT sender_id FROM chat_messages WHERE room_id = ? AND message = ?', [roomAB, '위조 시도']);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].sender_id, bob);
});

test('register에 다른 id를 보내도 토큰 사용자로만 등록되고 통화 요청을 가로챌 수 없다', async () => {
  const a = await connect(alice);
  const b = await connect(bob);
  const c = await connect(carol);
  b.emit('register');
  await h.sleep(100);
  // carol이 bob으로 등록하려 한다
  c.emit('register', { userId: String(bob) });
  await h.sleep(100);

  const toBob = h.waitFor(b, 'incomingCall');
  const toCarol = h.waitFor(c, 'incomingCall', 500);
  a.emit('register');
  await h.sleep(100);
  // 발신자 필드를 위조해도 서버는 토큰 사용자로 바꾼다
  a.emit('call', { callee: String(bob), caller: String(carol), offer: { sdp: 'x' } });

  const got = await toBob;
  assert.ok(got, 'bob이 통화 요청을 받아야 한다');
  assert.equal(got.caller, String(alice));
  assert.equal(await toCarol, null, 'carol은 bob 앞으로 온 요청을 받으면 안 된다');
});

test('수락한 통화의 종료를 두 번 보내도 통화 기록은 한 번만 늘어난다', async () => {
  const a = await connect(alice);
  const b = await connect(bob);
  a.emit('register');
  b.emit('register');
  await h.sleep(100);

  const accepted = h.waitFor(a, 'callAccepted');
  b.emit('acceptCall', { caller: String(alice) });
  assert.equal((await accepted).acceptor, String(bob));

  const ended = h.waitFor(b, 'callEnded');
  a.emit('endCall', { target: String(bob) });
  a.emit('endCall', { target: String(bob) });
  assert.ok(await ended);
  await h.sleep(300);

  const [rows] = await conn.query('SELECT count FROM call_partners WHERE user_id = ? AND partner_id = ?', [alice, bob]);
  assert.equal(rows.length, 1);
  assert.equal(rows[0].count, 1);
});

test('수락하지 않은 상대와의 통화 종료는 기록되지 않는다', async () => {
  const c = await connect(carol);
  c.emit('register');
  await h.sleep(100);
  c.emit('endCall', { target: String(alice) });
  await h.sleep(300);
  const [rows] = await conn.query('SELECT id FROM call_partners WHERE user_id = ? AND partner_id = ?', [carol, alice]);
  assert.equal(rows.length, 0);
});
