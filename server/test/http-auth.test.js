// REST API 인증·인가 회귀검사: 토큰 없음, 잘못된 토큰, 타인 리소스 접근
const { test, before, after } = require('node:test');
const assert = require('node:assert/strict');
const jwt = require('jsonwebtoken');
const h = require('./helpers');

let conn;
let srv;
let alice; let bob; let carol;
let aliceToken;
let roomAB;

before(async () => {
  conn = await h.connectDb();
  await h.resetDb(conn);
  alice = await h.createUser(conn, 'alice', '여성');
  bob = await h.createUser(conn, 'bob', '남성');
  carol = await h.createUser(conn, 'carol', '여성');
  aliceToken = h.tokenFor(alice);
  // bob과 carol만 참여한 채팅방
  const [room] = await conn.query('INSERT INTO chat_rooms (user1_id, user2_id) VALUES (?, ?)', [bob, carol]);
  roomAB = room.insertId;
  await conn.query('INSERT INTO chat_messages (room_id, sender_id, message) VALUES (?, ?, ?)', [roomAB, bob, 'secret']);
  srv = await h.startServer(5101);
});

after(async () => {
  await h.stopServer(srv);
  await conn.end();
});

const protectedRoutes = () => [
  ['GET', '/match'],
  ['GET', `/call-history/${alice}`],
  ['GET', `/chat-rooms/${alice}`],
  ['GET', `/chat-messages/${roomAB}`],
  ['GET', `/date-partners/${alice}`],
  ['GET', `/user-profile/${alice}`],
  ['GET', `/users/${alice}`],
  ['PUT', `/users/${alice}/location`],
  ['DELETE', `/users/${alice}`],
  ['POST', '/call-partner/step'],
  ['POST', '/api/call-history'],
  ['POST', '/upload-profile-image'],
];

test('토큰이 없으면 보호된 API는 401', async () => {
  for (const [method, path] of protectedRoutes()) {
    const res = await h.request(srv.baseUrl, method, path, { body: method === 'GET' ? undefined : {} });
    assert.equal(res.status, 401, `${method} ${path}`);
  }
});

test('형식이 틀리거나 다른 키로 서명했거나 만료된 토큰은 401', async () => {
  const badTokens = {
    garbage: 'not-a-jwt',
    otherSecret: h.tokenFor(alice, 'another-secret-0123456789abcdef0123456789'),
    expired: h.tokenFor(alice, h.JWT_SECRET, { expiresIn: -10 }),
    // 서명 알고리즘 none 토큰
    algNone: jwt.sign({ id: alice }, '', { algorithm: 'none' }),
    // 숫자 id가 아닌 토큰
    nonNumericId: jwt.sign({ id: 'admin' }, h.JWT_SECRET, { algorithm: 'HS256' }),
  };
  for (const [name, token] of Object.entries(badTokens)) {
    const res = await h.request(srv.baseUrl, 'GET', `/call-history/${alice}`, { token });
    assert.equal(res.status, 401, name);
  }
});

test('본인 토큰으로는 본인 리소스를 조회할 수 있다', async () => {
  const res = await h.request(srv.baseUrl, 'GET', `/call-history/${alice}`, { token: aliceToken });
  assert.equal(res.status, 200);
  assert.deepEqual(res.json.partners, []);
});

test('경로의 사용자 id가 토큰과 다르면 403', async () => {
  const cases = [
    ['GET', `/call-history/${bob}`],
    ['GET', `/chat-rooms/${bob}`],
    ['GET', `/date-partners/${bob}`],
    ['PUT', `/users/${bob}/location`, { latitude: 37.5, longitude: 127 }],
  ];
  for (const [method, path, body] of cases) {
    const res = await h.request(srv.baseUrl, method, path, { token: aliceToken, body });
    assert.equal(res.status, 403, `${method} ${path}`);
  }
  const [rows] = await conn.query('SELECT latitude FROM users WHERE id = ?', [bob]);
  assert.equal(rows[0].latitude, null, '타인 위치가 바뀌면 안 된다');
});

test('타인 계정 삭제 요청은 403이고 계정이 남아 있다', async () => {
  const res = await h.request(srv.baseUrl, 'DELETE', `/users/${bob}`, { token: aliceToken });
  assert.equal(res.status, 403);
  const [rows] = await conn.query('SELECT id FROM users WHERE id = ?', [bob]);
  assert.equal(rows.length, 1);
});

test('참여하지 않은 채팅방의 메시지는 403이고 참여자는 200', async () => {
  const denied = await h.request(srv.baseUrl, 'GET', `/chat-messages/${roomAB}`, { token: aliceToken });
  assert.equal(denied.status, 403);
  assert.ok(!denied.text.includes('secret'));

  const allowed = await h.request(srv.baseUrl, 'GET', `/chat-messages/${roomAB}`, { token: h.tokenFor(bob) });
  assert.equal(allowed.status, 200);
  assert.equal(allowed.json.messages[0].message, 'secret');
});

test('사진 공개(2단계) 전 상대의 프로필 사진은 403', async () => {
  await conn.query('INSERT INTO call_partners (user_id, partner_id, count, step) VALUES (?, ?, 1, 1)', [alice, bob]);
  const res = await h.request(srv.baseUrl, 'GET', `/user-profile/${bob}`, { token: aliceToken });
  assert.equal(res.status, 403);
  // 통화한 적 없는 사용자도 403
  const stranger = await h.request(srv.baseUrl, 'GET', `/user-profile/${carol}`, { token: aliceToken });
  assert.equal(stranger.status, 403);
});

test('통화한 적 없는 상대에게 단계 동의를 보내면 404이고 기록이 생기지 않는다', async () => {
  const res = await h.request(srv.baseUrl, 'POST', '/call-partner/step', {
    token: aliceToken, body: { partnerId: carol, agree: true, nextStep: 2 },
  });
  assert.equal(res.status, 404);
  const [rows] = await conn.query('SELECT id FROM call_partners WHERE user_id = ? AND partner_id = ?', [alice, carol]);
  assert.equal(rows.length, 0);
});

test('본문의 user_id를 바꿔도 토큰 사용자 기준으로만 동의가 기록된다', async () => {
  // alice가 bob의 행을 조작하려고 user_id를 bob으로 보낸다
  await conn.query('INSERT INTO call_partners (user_id, partner_id, count, step) VALUES (?, ?, 1, 1)', [bob, alice]);
  const res = await h.request(srv.baseUrl, 'POST', '/call-partner/step', {
    token: aliceToken, body: { user_id: bob, partnerId: bob, agree: true, nextStep: 2 },
  });
  assert.equal(res.status, 200);
  const [[aliceRow]] = await conn.query('SELECT my_agree FROM call_partners WHERE user_id = ? AND partner_id = ?', [alice, bob]);
  const [[bobRow]] = await conn.query('SELECT my_agree, partner_agree FROM call_partners WHERE user_id = ? AND partner_id = ?', [bob, alice]);
  assert.equal(aliceRow.my_agree, 1);
  assert.equal(bobRow.my_agree, 0, 'bob 본인의 동의는 바뀌면 안 된다');
  assert.equal(bobRow.partner_agree, 1);
});

test('서버가 중계한 수락 통화가 없으면 통화내역 저장은 403', async () => {
  const res = await h.request(srv.baseUrl, 'POST', '/api/call-history', {
    token: aliceToken, body: { partner_id: carol, date: new Date().toISOString() },
  });
  assert.equal(res.status, 403);
  const [rows] = await conn.query('SELECT id FROM call_partners WHERE user_id = ? AND partner_id = ?', [alice, carol]);
  assert.equal(rows.length, 0);
});

test('외부 API 키가 없으면 AI 중계 API는 외부 호출 없이 503', async () => {
  const stt = await h.request(srv.baseUrl, 'POST', '/api/analysis', { token: aliceToken, body: { conversation: 'A: 안녕' } });
  assert.equal(stt.status, 503);
});
