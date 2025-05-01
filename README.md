# 다온 (Daon) - AI 기반 소개팅 어플리케이션

[![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev)
[![WebRTC](https://img.shields.io/badge/WebRTC-DA291C?style=for-the-badge&logo=webrtc&logoColor=white)](https://webrtc.org/)
[![ML Kit](https://img.shields.io/badge/ML%20Kit-FF6F00?style=for-the-badge&logo=google&logoColor=white)](https://developers.google.com/ml-kit)
[![OpenAI](https://img.shields.io/badge/OpenAI-412991?style=for-the-badge&logo=openai&logoColor=white)](https://openai.com/)

**다온**은 Flutter를 기반으로 개발된 소개팅 어플리케이션입니다. 영상 통화 중 얼굴을 가리는 기능, AI를 활용한 대화 분석 및 소개팅 성사 예측 기능을 제공하여 사용자에게 새롭고 흥미로운 경험을 선사합니다.

## ✨ 주요 기능

1.  **얼굴 가리기 영상 통화**:
    *   WebRTC를 이용한 실시간 영상 통화 기능을 제공합니다.
    *   Google ML Kit의 Face Detection 기술을 활용하여 통화 중 상대방의 얼굴을 실시간으로 감지하고, 선택된 마스크 이미지로 가려줍니다. (프라이버시 보호 및 재미 요소)

2.  **AI 대화 분석 (STT & GPT)**:
    *   영상 통화 중 나누는 대화를 STT(Speech-to-Text) 기술을 통해 텍스트로 변환합니다.
    *   변환된 대화 스크립트를 OpenAI의 GPT 모델 API로 전송하여 대화 내용을 분석하고 요약합니다.

3.  **소개팅 성사 예측**:
    *   분석된 대화 내용과 기타 요소를 기반으로, 자체적으로 학습시킨 예측 모델을 사용하여 소개팅의 성사 가능성을 예측합니다. (예: "나는 솔로" 데이터 학습)

4.  **기타 기능**:
    *   회원 가입 및 로그인
    *   사용자 간 매칭 (현재 랜덤 매칭)
    *   대화 분석 및 예측 결과 조회 (카드 형식 UI)
    *   데이트 장소 추천 (구현 예정)
    *   채팅 기능 (구현 예정)
    *   설정 (프로필 수정, 로그아웃, 회원 탈퇴 등)

## 🛠️ 기술 스택

*   **Frontend**: Flutter
*   **Real-time Communication**: Flutter WebRTC, Socket.IO (시그널링 서버 연동 필요)
*   **Face Detection**: Google ML Kit Face Detection
*   **AI (Text Generation)**: OpenAI API (GPT)
*   **AI (Prediction)**: 자체 학습 모델 (서버 연동 필요)
*   **State Management**: Provider (또는 다른 상태 관리 라이브러리)
*   **HTTP Client**: http
*   **Permissions**: permission_handler
*   **Local Storage**: shared_preferences
*   **Image Handling**: image_picker, cached_network_image, image
*   **Temporary File System**: path_provider

## 🎭 얼굴 마스킹 구현 상세

얼굴 마스킹 기능은 다음과 같은 단계로 구현되었습니다.

1.  **WebRTC 스트림 렌더링**: `flutter_webrtc`의 `RTCVideoRenderer`를 사용하여 상대방의 비디오 스트림을 화면에 표시합니다.
2.  **프레임 캡처**: `RTCVideoRenderer`를 `RepaintBoundary` 위젯으로 감싸고, 주기적으로 `toImage()` 메서드를 호출하여 현재 렌더링된 프레임을 `ui.Image` 객체로 캡처합니다.
3.  **이미지 처리**: 캡처된 `ui.Image`를 `ByteData`로 변환하고, `path_provider`를 사용하여 임시 파일(PNG)로 저장합니다.
4.  **얼굴 감지**: `google_mlkit_face_detection` 라이브러리를 사용하여 임시 파일로부터 `InputImage`를 생성하고, `FaceDetector.processImage()`를 호출하여 이미지 내 얼굴의 위치(`boundingBox`)를 감지합니다.
5.  **마스크 로딩 및 오버레이**:
    *   `FaceMaskOverlay` 위젯에서 `maskAssetPath`에 지정된 마스크 이미지를 `rootBundle.load`를 통해 `ui.Image`로 로드합니다.
    *   `CustomPaint` 위젯과 `_FaceMaskPainter`를 사용하여 캡처된 원본 프레임(`ui.Image`) 위에, 감지된 얼굴의 `boundingBox` 좌표에 맞춰 마스크 이미지(`ui.Image`)를 덧그립니다. 좌표 변환 로직을 포함하여 정확한 위치에 마스크가 표시되도록 합니다.

## 📱 화면 구성

*   **시작 페이지**: 앱 소개 및 로그인/회원가입 버튼
*   **회원가입 페이지**: 사용자 정보 입력 (아이디, 비밀번호, 성별, 주소, 닉네임, 프로필 사진)
*   **로그인 페이지**: 아이디, 비밀번호 입력
*   **메인 페이지**: 하단 네비게이션 바 (메인, 데이트 장소 추천, 채팅방, 설정), 상대방 연결 버튼, 상단 네비게이션 바 (대화 분석, 예측 결과)
*   **영상통화 페이지**: 얼굴 가리기 기능이 적용된 영상 통화 화면
*   **대화분석 페이지**: 통화별 대화 분석 결과 목록 (카드 UI), 상세 보기 (모달)
*   **예측 페이지**: 통화별 소개팅 성사 예측 결과 목록 (카드 UI), 상세 보기 (모달)
*   **데이트 장소 추천 페이지**: (구현 예정)
*   **채팅방 페이지**: (구현 예정)
*   **설정 페이지**: 주소 수정, 로그아웃, 회원 탈퇴

## 🚀 시작하기

1.  **저장소 클론**:
    ```bash
    git clone https://your-repository-url/daon.git
    cd daon
    ```
2.  **필요한 라이브러리 설치**:
    ```bash
    flutter pub add flutter_webrtc socket_io_client permission_handler path_provider google_mlkit_face_detection image http shared_preferences provider image_picker cached_network_image flutter_svg intl cupertino_icons flutter_lints
    ```
    *(참고: `pubspec.yaml`에 직접 추가하는 대신 터미널 명령어를 사용합니다.)*
3.  **Flutter 앱 실행**:
    ```bash
    flutter run
    ```

## 🤝 기여하기

프로젝트에 기여하고 싶으시다면 언제든지 환영합니다! 이슈를 등록하거나 Pull Request를 보내주세요.

## 📄 라이선스

(라이선스를 명시하고 싶다면 여기에 추가하세요. 예: MIT License)

---

Made by **다온**

