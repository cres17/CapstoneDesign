// 잘못된 소켓 payload나 DB 오류가 서버 프로세스를 종료시키지 않는지 확인한다
const { test, before, beforeEach, after } = require('node:test');
const assert = require('node:assert/strict');
const h = require('./helpers');

let conn;
let srv;
let alice;

before(async () => {
  conn = await h.connectDb();
  await h.resetDb(conn);
  alice = await h.createUser(conn, 'alice', '여성');
  srv = await h.startServer(5103);
});

// 앞 테스트에서 서버가 종료됐다면 다시 띄워 각 이벤트를 독립적으로 판정한다
beforeEach(async () => {
  if (srv.exited) srv = await h.startServer(5103);
});

after(async () => {
  await h.stopServer(srv);
  await conn.end();
});

async function assertAlive(label) {
  await h.sleep(300);
  assert.equal(srv.exited, false, `${label} 이후 서버가 종료됨 (exit=${srv.exitCode})\n${srv.output.slice(-1500)}`);
  const res = await h.request(srv.baseUrl, 'GET', `/call-history/${alice}`, { token: h.tokenFor(alice) });
  assert.equal(res.status, 200, `${label} 이후 HTTP 응답 실패`);
}

// 인증된 클라이언트라면 누구나 보낼 수 있는 이벤트들
const events = ['call', 'callAnswered', 'callError', 'ice-candidate', 'endCall', 'callRejected', 'acceptCall', 'joinRoom', 'sendMessage', 'answer'];

for (const event of events) {
  test(`${event}를 payload 없이 보내도 서버가 살아 있다`, async () => {
    const s = await h.connectSocket(srv.baseUrl, h.tokenFor(alice));
    s.emit(event);
    await assertAlive(`${event}()`);
    s.emit(event, null);
    await assertAlive(`${event}(null)`);
    s.close();
  });
}

test('DB 쿼리가 실패해도 요청은 500으로 끝나고 서버는 살아 있다', async () => {
  // 서버가 사용하는 테이블을 잠시 없애 쿼리 실패를 만든다
  await conn.query('RENAME TABLE call_partners TO call_partners_tmp');
  try {
    const res = await h.request(srv.baseUrl, 'GET', `/call-history/${alice}`, { token: h.tokenFor(alice) });
    assert.equal(res.status, 500);
    assert.ok(!res.text.includes('call_partners'), 'DB 오류 내용을 응답에 노출하지 않는다');
  } finally {
    await conn.query('RENAME TABLE call_partners_tmp TO call_partners');
  }
  await assertAlive('DB 오류');
});
