// 테스트 공용 도구: 실제 MySQL에 스키마를 적용하고, server.js를 별도 프로세스로 띄운다.
// 서버를 자식 프로세스로 실행하므로 예외로 프로세스가 종료되는지도 관찰할 수 있다.
const { spawn } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');
const mysql = require('mysql2/promise');
const jwt = require('jsonwebtoken');
const { io: ioClient } = require('socket.io-client');

const JWT_SECRET = process.env.TEST_JWT_SECRET || 'test-secret-0123456789abcdef0123456789abcdef';
const DB = {
  host: process.env.DB_HOST || '127.0.0.1',
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'root',
  database: process.env.DB_DATABASE || 'daon_test',
};

async function connectDb() {
  return mysql.createConnection({ ...DB, multipleStatements: true });
}

// 매 테스트 파일 시작 시 테이블을 지우고 schema.sql로 다시 만든다
async function resetDb(conn) {
  await conn.query(`
    SET FOREIGN_KEY_CHECKS = 0;
    DROP TABLE IF EXISTS chat_messages, chat_rooms, call_partners, users;
    SET FOREIGN_KEY_CHECKS = 1;
  `);
  const schema = fs.readFileSync(path.join(__dirname, '..', 'schema.sql'), 'utf8');
  await conn.query(schema);
}

async function createUser(conn, username, gender = '남성') {
  const [result] = await conn.query(
    'INSERT INTO users (username, password_hash, nickname, gender) VALUES (?, ?, ?, ?)',
    [username, 'not-used-in-tests', `${username}-nick`, gender]
  );
  return result.insertId;
}

function tokenFor(id, secret = JWT_SECRET, options = {}) {
  return jwt.sign({ id, username: `u${id}`, nickname: `n${id}` }, secret, { algorithm: 'HS256', expiresIn: '1h', ...options });
}

// server.js를 띄우고 listen 로그가 나올 때까지 기다린다
async function startServer(port) {
  const child = spawn(process.execPath, [path.join(__dirname, '..', 'server.js')], {
    cwd: path.join(__dirname, '..'),
    env: {
      ...process.env,
      PORT: String(port),
      JWT_SECRET,
      DB_HOST: DB.host,
      DB_PORT: String(DB.port),
      DB_USER: DB.user,
      DB_PASSWORD: DB.password,
      DB_DATABASE: DB.database,
      // 외부 API 키는 비워 두어 실제 외부 호출이 일어나지 않게 한다
      OPENAI_API_KEY: '',
      CLOVA_SPEECH_SECRET: '',
      CLOVA_SPEECH_URL: '',
      TOUR_API_KEY: '',
      MODEL_SERVER_URL: 'http://127.0.0.1:9/analyze',
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  const state = { child, output: '', exited: false, exitCode: null };
  child.stdout.on('data', (d) => { state.output += d; });
  child.stderr.on('data', (d) => { state.output += d; });
  child.on('exit', (code, signal) => { state.exited = true; state.exitCode = code ?? signal; });

  const deadline = Date.now() + 15000;
  while (!state.output.includes('실행 중')) {
    if (state.exited) throw new Error(`서버가 시작 전에 종료됨:\n${state.output}`);
    if (Date.now() > deadline) throw new Error(`서버 시작 대기 시간 초과:\n${state.output}`);
    await sleep(50);
  }
  state.baseUrl = `http://127.0.0.1:${port}`;
  return state;
}

async function stopServer(state) {
  if (!state || state.exited) return;
  state.child.kill('SIGTERM');
  await new Promise((resolve) => state.child.once('exit', resolve));
}

function sleep(ms) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

async function request(baseUrl, method, urlPath, { token, body } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers['Content-Type'] = 'application/json';
  const res = await fetch(baseUrl + urlPath, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* 본문이 JSON이 아닐 수 있다 */ }
  return { status: res.status, json, text };
}

// 토큰으로 소켓을 연결한다. 연결 실패 시 Error를 던진다
function connectSocket(baseUrl, token) {
  return new Promise((resolve, reject) => {
    const socket = ioClient(baseUrl, {
      auth: token === undefined ? {} : { token },
      transports: ['websocket'],
      reconnection: false,
      forceNew: true,
    });
    socket.once('connect', () => resolve(socket));
    socket.once('connect_error', (err) => { socket.close(); reject(err); });
  });
}

// 이벤트를 기다린다. 시간 안에 오지 않으면 null
function waitFor(socket, event, ms = 1000) {
  return new Promise((resolve) => {
    const timer = setTimeout(() => { socket.off(event, onEvent); resolve(null); }, ms);
    function onEvent(payload) { clearTimeout(timer); resolve(payload ?? {}); }
    socket.once(event, onEvent);
  });
}

module.exports = {
  JWT_SECRET, connectDb, resetDb, createUser, tokenFor, startServer, stopServer,
  sleep, request, connectSocket, waitFor,
};
