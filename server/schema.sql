-- 다온 서버 MySQL 스키마 (server.js가 사용하는 테이블·컬럼 기준)
-- 사용: mysql -u <user> -p <database> < server/schema.sql

CREATE TABLE IF NOT EXISTS users (
  id INT AUTO_INCREMENT PRIMARY KEY,
  username VARCHAR(255) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  nickname VARCHAR(255) NOT NULL UNIQUE,
  interests TEXT,
  gender VARCHAR(10) NOT NULL,            -- '남성' | '여성'
  latitude DOUBLE NULL,
  longitude DOUBLE NULL,
  profile_image VARCHAR(255) NULL,        -- 'assets/profile/<id>.png'
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) DEFAULT CHARSET = utf8mb4;

-- 통화 상대와 관계 단계. 한 쌍마다 방향별로 두 행(user→partner, partner→user)을 둔다.
-- step: 1 통화 → 2 사진 공개 → 3 데이트
-- my_agree / partner_agree: 0 미동의, 1 사진 공개 동의, 2 데이트 동의
CREATE TABLE IF NOT EXISTS call_partners (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user_id INT NOT NULL,
  partner_id INT NOT NULL,
  count INT NOT NULL DEFAULT 0,
  step TINYINT NOT NULL DEFAULT 1,
  my_agree TINYINT NOT NULL DEFAULT 0,
  partner_agree TINYINT NOT NULL DEFAULT 0,
  updated_at DATETIME DEFAULT CURRENT_TIMESTAMP,
  UNIQUE KEY uq_call_partner (user_id, partner_id),
  FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (partner_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4;

-- 3단계(데이트)에 양쪽이 동의하면 생성되는 1:1 채팅방
CREATE TABLE IF NOT EXISTS chat_rooms (
  id INT AUTO_INCREMENT PRIMARY KEY,
  user1_id INT NOT NULL,
  user2_id INT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (user1_id) REFERENCES users(id) ON DELETE CASCADE,
  FOREIGN KEY (user2_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4;

CREATE TABLE IF NOT EXISTS chat_messages (
  id INT AUTO_INCREMENT PRIMARY KEY,
  room_id INT NOT NULL,
  sender_id INT NOT NULL,
  message TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_room_created (room_id, created_at),
  FOREIGN KEY (room_id) REFERENCES chat_rooms(id) ON DELETE CASCADE,
  FOREIGN KEY (sender_id) REFERENCES users(id) ON DELETE CASCADE
) DEFAULT CHARSET = utf8mb4;
