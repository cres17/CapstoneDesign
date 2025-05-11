# 다온 (Daon) - AI 기반 소개팅 어플리케이션

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![WebRTC](https://img.shields.io/badge/WebRTC-DA291C?style=for-the-badge&logo=webrtc&logoColor=white)](https://webrtc.org/)
[![ML Kit](https://img.shields.io/badge/ML%20Kit-FF6F00?style=for-the-badge&logo=google&logoColor=white)](https://developers.google.com/ml-kit)
[![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white)](https://openai.com/)

**다온**은 Flutter 기반의 AI 소개팅 어플리케이션입니다.  
실시간 영상통화, 얼굴 마스킹, AI 대화 분석, 소개팅 성사 예측, **실시간 채팅**, **데이트장소 추천** 등 다양한 기능을 제공합니다.

---

## ✨ 주요 기능 및 사용 기술

### 1. 실시간 영상통화 & 얼굴 마스킹
- **WebRTC**(`flutter_webrtc`)로 실시간 영상통화 구현
- **Google ML Kit Face Detection**으로 영상 프레임에서 얼굴 실시간 감지
- **CustomPaint**와 **dart:ui**로 얼굴 위치에 마스크 이미지 오버레이
- **RepaintBoundary**로 프레임 캡처, **path_provider**로 임시 파일 저장

### 2. AI 기반 대화 분석
- 통화 중 음성 녹음 → **네이버 클로바 Speech API**로 STT(음성→텍스트)
- 변환된 텍스트를 **OpenAI GPT API**로 전송, 대화 요약/감정/분위기 분석

### 3. 소개팅 성사 예측
- 대화 분석 결과와 메타데이터(길이, 감정 등)를 자체 **머신러닝 예측 모델**에 입력
- 예측 결과(성사 확률, 주요 근거 등)를 카드 UI로 시각화

### 4. 실시간 채팅 기능
- **Socket.IO** 기반의 1:1 채팅 및 채팅방 목록
- 메시지 실시간 송수신, 채팅방 입장/퇴장, 채팅 UI 제공

### 5. 데이트장소 추천
- 사용자의 위치와 상대방 닉네임을 기반으로, 두 사람의 위치를 고려한 데이트 장소 추천
- **지도 API**(한국 관광공사 맛집 API)와 연동, 카드형 UI로 추천 장소 제공

### 6. 기타 기능
- **회원가입/로그인**: 사용자 정보 입력 및 인증
- **랜덤 매칭**: 서버에 접속한 사용자 중 무작위 연결
- **대화 분석/예측 결과 조회**: 카드형 UI, 상세 모달
- **설정**: 프로필 수정, 로그아웃, 회원탈퇴 등

---

## 🛠️ 사용한 주요 알고리즘 및 API

- **얼굴 인식**: Google ML Kit Face Detection (bounding box 추출)
- **음성 인식(STT)**: 네이버 클로바 Speech API
- **대화 분석/요약**: OpenAI GPT API (텍스트 요약, 감정 분석)
- **성사 예측**: 자체 머신러닝 모델 (분류/회귀, scikit-learn, TensorFlow 등 활용 가능)
- **실시간 통신**: WebRTC (flutter_webrtc), Socket.IO (시그널링 서버)
- **지도/장소 추천**: 한국 관광공사 맛집 API 등
- **상태 관리**: Provider
- **이미지 처리**: image, image_picker, cached_network_image 등

---

## 📱 화면 구성

- **시작 페이지**: 앱 소개, 로그인/회원가입 버튼
- **회원가입 페이지**: 아이디, 비밀번호, 성별, 주소, 닉네임, 프로필 사진 입력
- **로그인 페이지**: 아이디, 비밀번호 입력
- **메인 페이지**: 하단 네비게이션(메인, 데이트 장소 추천, 채팅방, 설정), 상대방 연결 버튼, 상단 네비게이션(대화 분석, 예측 결과)
- **영상통화 페이지**: 얼굴 마스킹 적용된 영상통화
- **대화분석 페이지**: 통화별 분석 결과 카드, 상세 모달
- **예측 페이지**: 통화별 성사 예측 결과 카드, 상세 모달
- **데이트 장소 추천 페이지**: 두 사람의 위치 기반 추천 장소 카드 UI
- **채팅방 페이지**: 1:1 채팅, 채팅방 목록, 실시간 메시지
- **설정 페이지**: 주소 수정, 로그아웃, 회원탈퇴

---

## 🚀 시작하기

1. **저장소 클론**
    ```bash
    git clone https://your-repository-url/daon.git
    cd daon
    ```
2. **필요한 라이브러리 설치**
    ```bash
    flutter pub add flutter_webrtc socket_io_client permission_handler path_provider google_mlkit_face_detection image http shared_preferences provider image_picker cached_network_image flutter_svg intl cupertino_icons flutter_lints
    ```
    *(pubspec.yaml에 직접 추가하지 않고 터미널 명령어로 설치)*
3. **Flutter 앱 실행**
    ```bash
    flutter run
    ```

---

## 🤝 기여하기

프로젝트에 기여하고 싶으시다면 언제든지 환영합니다! 이슈를 등록하거나 Pull Request를 보내주세요.

## 📄 라이선스

(라이선스를 명시하고 싶다면 여기에 추가하세요. 예: MIT License)

---

Made by **다온**

