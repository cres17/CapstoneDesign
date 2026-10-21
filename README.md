# 다온 — 대화와 호감도 분석 소개팅 앱

Flutter 앱과 Node.js 서버, Python 모델 서버를 함께 사용하는 졸업 프로젝트입니다. 영상통화·얼굴 마스킹·채팅·대화 분석·호감도 예측·장소 추천 관련 코드를 포함합니다.

현재 코드는 실습 환경의 서버 주소와 경로를 포함합니다. 앱 의존성만 설치하면 전체 기능이 바로 연결되는 형태는 아니며, 아래 서버·DB·외부 API 설정이 필요합니다.

## 기능과 구성

| 기능 | 주요 구현 |
|---|---|
| 영상통화와 신호 교환 | flutter_webrtc, Socket.IO |
| 얼굴 감지와 마스크 표시 | Google ML Kit Face Detection, Flutter 그리기 |
| 대화 음성 처리 | 녹음 서비스, Clova Speech 연동 |
| 대화 분석 | OpenAI API 연동 |
| 호감도 점수 요청 | Flutter PredictionService → Python Flask 서버 |
| 로그인·매칭·채팅 | Express, Socket.IO, MySQL 관련 코드 |
| 데이트 장소 | 관광 API 연동 화면과 위치 기반 추천 코드 |

구현 파일이 있다는 것과 실제 기기·서버·API가 연결된 상태에서 검증됐다는 것은 구분해야 합니다. 카메라·마이크·위치 권한과 네트워크 설정도 필요합니다.

## 학습 모델과 현재 서빙

학습 실험은 [likeability_expectation](https://github.com/cres17/likeability_expectation)에 있습니다. Soft Labeling, KoBigBird 이진 분류, GNTB·CNN·LSTM을 사용하는 BiERU 회귀는 별도의 실험입니다. 하나의 이중 출력 모델로 표현하지 않습니다.

현재 [server/model_server.py](server/model_server.py)의 실제 처리 순서는 다음과 같습니다.

1. W&B에서 `kobigbird-male-mlp-pearson:latest`와 `kobigbird-female-mlp-pearson:latest` 아티팩트를 다운로드합니다.
2. `AutoModelForSequenceClassification`과 `AutoTokenizer`로 적재합니다.
3. `POST /analyze`의 `input_text`와 `gender`를 읽습니다.
4. 입력을 최대 512토큰으로 잘라 추론하고 sigmoid 점수를 `score`로 반환합니다.

이 서버 코드에는 BiERU 클래스를 직접 생성하는 경로가 없습니다. 학습 노트북의 모델을 배포하려면 클래스·가중치 저장 형식·토크나이저가 서버의 적재 방식과 맞는지 확인해야 합니다. W&B의 `latest`가 가리키는 실제 모델 버전도 별도로 고정해야 같은 결과를 재현할 수 있습니다.

### 기존 프로젝트 보고 수치

| 관점 | 분류 정확도 | 분류 F1 | 회귀 MSE | 회귀 R² |
|---|---:|---:|---:|---:|
| 남성 | 0.607 | 0.756 | 0.056 | 0.587 |
| 여성 | 0.536 | 0.606 | 0.045 | 0.503 |

기존 문서의 기록이며 현재 서버를 재실행하여 확인한 성능은 아닙니다. 평가 데이터 분할·실험 설정·모델 아티팩트를 연결해야 배포 모델의 성능과 비교할 수 있습니다. 사용자 48명의 기능 만족도 4.22/5.0 역시 설문 기록이며 모델 정확도와 다른 지표입니다.

## 실행 준비

### 1. 저장소와 Flutter 의존성

`pubspec.yaml`의 Dart 조건은 `^3.7.2`입니다. 이 조건을 지원하는 Flutter와 사용할 플랫폼 SDK를 준비합니다.

```bash
git clone https://github.com/cres17/CapstoneDesign.git
cd CapstoneDesign
flutter pub get
```

기존 프로젝트를 설치할 때 패키지 목록을 다시 `flutter pub add`로 추가할 필요는 없습니다.

### 2. Node.js 서버와 MySQL

Node.js·npm·MySQL을 준비합니다. [server/package.json](server/package.json)의 의존성을 설치합니다.

```bash
cd server
npm install
```

현재 `server.js`는 `multer`를 사용하지만 server/package.json에는 선언되어 있지 않습니다. 서버를 실행하려면 검토한 버전의 multer를 추가로 설치하고 의존성에 반영해야 합니다.

`server/.env`에 아래 환경변수를 설정합니다. 실제 값을 Git에 커밋하지 않습니다.

```dotenv
DB_HOST=127.0.0.1
DB_USER=
DB_PASSWORD=
DB_DATABASE=
JWT_SECRET=
PORT=5000
```

MySQL 데이터베이스와 서버 쿼리에 필요한 테이블을 준비해야 합니다. [capstone_user_database/user.sql](capstone_user_database/user.sql)은 users 테이블 자료이며, [daon/users.sql](daon/users.sql)과 [user_database/user.sql](user_database/user.sql)은 SQL Server 형식입니다. 이 파일들을 모두 MySQL에 실행하는 설치 절차로 취급하면 안 됩니다. 현재 저장소에는 서버 전체 스키마를 한 번에 구성하는 통합 마이그레이션이 없습니다.

프로필 업로드 경로도 `server.js`의 Windows 절대 경로를 실행 환경에 맞는 쓰기 가능한 폴더로 변경해야 합니다. 설정과 필요한 테이블 준비 후 server 폴더에서 실행합니다.

```bash
npm start
```

기본 포트는 5000입니다.

### 3. Python 호감도 모델 서버

별도 터미널에서 server 폴더로 이동한 뒤 가상환경을 준비합니다.

```bash
python3 -m venv .venv
source .venv/bin/activate
python -m pip install torch transformers flask wandb
wandb login
python model_server.py
```

Windows PowerShell의 활성화 명령은 `.venv\Scripts\Activate.ps1`입니다. torch는 사용하는 CPU/CUDA 환경에 맞춰 설치해야 합니다. 위 패키지는 코드의 직접 의존성이며, 검증된 버전 잠금 파일은 현재 없습니다.

W&B 계정에서 코드에 지정된 프로젝트와 두 모델 아티팩트에 접근할 수 있어야 합니다. 아티팩트에는 Hugging Face 로더가 읽을 수 있는 모델·토크나이저 파일이 필요합니다. 접근 권한이나 파일 형식이 맞지 않으면 시작 단계에서 실패합니다. 기본 포트는 5001이며 현재 Flask 실행 설정은 개발용입니다.

요청 형식:

```json
{
  "input_text": "분석할 대화",
  "gender": "male"
}
```

`gender`는 `male` 또는 `female`을 사용합니다.

### 4. 앱 주소와 외부 서비스 연결

- [lib/config/app_config.dart](lib/config/app_config.dart)의 서버 IP·포트를 실제 Node 서버 주소로 바꿉니다.
- [lib/services/prediction_service.dart](lib/services/prediction_service.dart)의 `http://<서버 IP>:5001/analyze`도 실제 모델 서버 주소로 바꿉니다. AppConfig만 수정해도 이 주소가 함께 바뀌지는 않습니다.
- Clova Speech, OpenAI, 관광 API 관련 서비스·화면의 설정을 본인 계정 값으로 확인합니다. 모든 외부 키를 읽는 공통 환경 설정이 마련된 것은 아닙니다.
- 기기에서 서버에 접근할 수 있는지, 카메라·마이크·위치 권한과 플랫폼 네트워크 설정이 맞는지 확인합니다.

그다음 저장소 루트에서 실행합니다.

```bash
flutter run
```

## 주요 경로

| 경로 | 역할 |
|---|---|
| [lib/screens](lib/screens) | 로그인·영상통화·채팅·분석·추천 화면 |
| [lib/services](lib/services) | 음성·분석·예측·인증·통신 서비스 |
| [lib/config/app_config.dart](lib/config/app_config.dart) | 앱의 기본 서버 주소 |
| [server/server.js](server/server.js) | Express·Socket.IO·MySQL 서버 |
| [server/model_server.py](server/model_server.py) | W&B 모델 적재와 Flask 예측 API |
| [pubspec.yaml](pubspec.yaml) | Flutter 의존성과 SDK 조건 |

## 검증 범위

설치 후 로그인·채팅·영상통화·STT·분석·예측을 순서대로 확인해야 합니다. 서버의 `npm test`는 현재 실제 테스트가 아니라 미구현 안내 후 실패하는 명령입니다. 전체 시스템의 자동 통합 테스트나 단일 배포 명령은 제공하지 않습니다.
