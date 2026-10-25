# 서버 회귀검사

실제 MySQL 8에 `schema.sql`을 적용하고 `server.js`를 별도 프로세스로 띄워 HTTP·Socket.IO로 검사한다. 서버를 자식 프로세스로 실행하므로 예외로 프로세스가 종료되는지도 확인한다. 외부 API(OpenAI·CLOVA·TourAPI·모델 서버)는 호출하지 않는다.

## 실행

```bash
docker run -d --name daon-mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=daon_test -p 3306:3306 mysql:8.0
cd server
npm ci
npm test
```

접속 정보는 `DB_HOST`, `DB_USER`, `DB_PASSWORD`, `DB_DATABASE` 환경변수로 바꿀 수 있다(기본값 `127.0.0.1 / root / root / daon_test`). 테스트는 시작할 때 테이블을 지우고 다시 만들므로 **운영 DB를 가리키지 않게 한다.** Node 22 이상이 필요하다.

## 검사 범위

| 파일 | 내용 |
|---|---|
| `test/http-auth.test.js` | 토큰 없음·위조·만료·`alg: none` 토큰 거부, 경로 id와 토큰 불일치 시 403, 미참여 채팅방 조회 거부, 사진 공개 전 프로필 거부, 본문 `user_id` 위조 무시, 수락 통화 없는 통화내역 저장 거부 |
| `test/socket-auth.test.js` | 소켓 인증, 미참여 채팅방 입장·전송 거부, `senderId`·`register` id·`caller` 위조 무시, 중복 통화 종료 1회 기록, 미수락 통화 종료 미기록 |
| `test/socket-robustness.test.js` | payload 없는 소켓 이벤트와 DB 쿼리 실패 후에도 서버 프로세스 생존 |

## 범위 밖

WebRTC 미디어 연결, 앱(Flutter) 화면 흐름, 외부 API 응답 처리, 여러 서버 프로세스 환경(통화 상태가 메모리에만 있음)은 검사하지 않는다.
