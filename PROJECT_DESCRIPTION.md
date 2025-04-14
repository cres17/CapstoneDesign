<소개팅 어플>
어플이름: 다온
핵심기능:
1.영상통화를 하면서 서로의 얼굴을 가리고 진행.
2. 대화를 하면서 stt를 통해 나눈스크립트를 openai api를 통해 gpt모델에게 대화분석 요청.
3. 대화를 분석한 뒤에 이 소개팅이 성사될 것인지 예측. (예측 모델은 우리가 직접 "나는솔로"티비 프로그램의 내용을 학습.)

페이지 구성:시작페이지, 회원가입페이지, 로그인페이지, 메인페이지, 영상통화 페이지, 대화분석페이지, 예측페이지, 데이트장소 추천페이지, 채팅방페이지, 설정페이지.

페이지마다 폴더를 구성.

1. 시작페이지: 회원가입, 로그인버튼.

2. 회원가입 페이지: 아이디, 비밀번호, 성별, 주소, 닉네임, 프로필사진 업로드. 이렇게 6가지를 기입.

3. 로그인 페이지: 아이디와 비밀번호를 적는 칸, 로그인 버튼. 지금은 로그인 구현을 못했으니, 로그인버튼을 누르면 바로 메인페이지로 넘어가도록 함.

4. 메인페이지: 아랫쪽에 네비게이션바들이 보이고, 네비게이션바는 메인페이지, 데이트장소 추천페이지, 채팅방 페이지, 설정페이지 이렇게 네가지가 있음. 중앙에는 "상대방과 연결하기" 버튼이 있는데, 이 버튼을 누르면 영상통화 페이지로 넘어가서 상대방과 영상통화 연결.
통화종료버튼을 누르면 알림창이 뜨면서 "대화분석페이지와 예측페이지에 분석된 내용이 있습니다"라는 문구가 나옴. 메인페이지 상단 네이게이션 바에 대화분석페이지와 예측페이지를 추가. 네브바 아이콘을 누르면 각 페이지로 이동.

5. 영상통화 페이지: 영상통화 페이지는 영상통화를 하는 페이지. 영상통화를 하면서 서로의 얼굴을 가리고 진행. 전화 매칭 알고리즘: "상대방과 연결하기" 버튼을 누르면 서버에 있는 사용자중에 랜덤으로 골라서 연결. "000와 연결하시겠습니까?"이런 문구 안나와도 됨. -> 바로 연결. 그리고 매칭되지 않은 사용자나 서버에 아무 이용자도 없다면 로딩화면이 나오도록 함.

6. 대화분석페이지: 카드 형식으로 위에부터 최근 통화했던부분에 대한 분석 결과 날짜와 대화상대가 보이도록 나와있음. 카드를 클릭하면 더 크게 모달창이 나오면서 분석 결과가 나옴.

7. 예측페이지: 카드형식으로 날짜와 대화상대방이 표시되어있는데, 카드를 클릭하면 예측결과가 나타나게 함.

8. 데이트장소 추천 페이지는 검색창에 상대방의 닉네임을 입력하면 상대방과 내 위치를 고려해서 추천 데이트장소가 카드형식으로 나옴.(아직 구현x)
설정 페이지는 주소 수정, 로그아웃버튼, 회원탈퇴버튼을 넣어주도록 하고 맨 아래 "made by daon".


주의할 점: 패키지나 라이브러리를 추가할 때 pubspec.yalm에 추가하지 말고 터미널에서 사용자가 직접 설치-> 터미널 설치 명령어로 응답.

# 얼굴 마스킹 기능 구현 (Face Masking Feature)

이 프로젝트는 Flutter와 WebRTC를 사용하여 영상 통화 기능을 구현하며, 통화 중 상대방의 얼굴을 감지하여 마스크 이미지로 가리는 기능을 포함합니다.

## 개요

영상 통화 시 상대방의 비디오 스트림에서 실시간으로 얼굴을 인식하고, 인식된 얼굴 영역 위에 미리 준비된 마스크 이미지를 오버레이하여 표시합니다. 이를 통해 사용자의 프라이버시를 보호하거나 재미 요소를 추가할 수 있습니다.

## 주요 기술 스택 및 도구

얼굴 마스킹 기능을 구현하기 위해 다음과 같은 주요 기술과 라이브러리가 사용되었습니다:

1.  **Flutter WebRTC (`flutter_webrtc`)**:
    *   WebRTC 프로토콜을 사용하여 P2P(Peer-to-Peer) 영상 통화 연결을 설정하고 비디오 스트림을 주고받습니다.
    *   `RTCVideoRenderer` 위젯을 통해 로컬 및 원격 비디오 스트림을 화면에 표시합니다.

2.  **Google ML Kit Face Detection (`google_mlkit_face_detection`)**:
    *   Google의 ML Kit 라이브러리를 사용하여 이미지나 비디오 프레임에서 얼굴을 감지합니다.
    *   얼굴의 위치(Bounding Box), 랜드마크(눈, 코, 입 등), 분류(웃음, 눈 감음 등) 정보를 얻는 데 사용됩니다. 이 프로젝트에서는 주로 **얼굴의 Bounding Box** 정보를 활용합니다.

3.  **RepaintBoundary & `dart:ui`**:
    *   `RepaintBoundary` 위젯으로 상대방 비디오를 렌더링하는 `RTCVideoView`를 감쌉니다.
    *   `RepaintBoundary`의 `toImage()` 메서드를 사용하여 특정 시점의 위젯 렌더링 결과를 `ui.Image` 객체로 캡처합니다. 이 캡처된 이미지가 얼굴 감지를 위한 입력으로 사용됩니다.

4.  **Path Provider (`path_provider`)**:
    *   캡처된 `ui.Image`를 ML Kit가 처리할 수 있는 형식(파일 경로)으로 변환하기 위해 사용됩니다.
    *   `toImage().toByteData(format: ui.ImageByteFormat.png)`를 통해 얻은 PNG 이미지 바이트를 기기의 임시 디렉토리에 파일로 저장합니다.

5.  **CustomPaint & `dart:ui`**:
    *   `CustomPaint` 위젯과 `CustomPainter`를 사용하여 캡처된 비디오 프레임 위에 마스크 이미지를 직접 그립니다.
    *   `_FaceMaskPainter`는 먼저 캡처된 비디오 프레임(`ui.Image`)을 캔버스에 그린 다음, ML Kit로 감지된 각 얼굴의 `boundingBox` 좌표를 기반으로 마스크 이미지(`ui.Image`)를 해당 위치에 맞게 크기를 조절하여 덧그립니다.

6.  **Flutter Assets**:
    *   얼굴에 씌울 마스크 이미지(`default_mask.png`)는 Flutter의 에셋 시스템을 통해 로드됩니다. (`rootBundle.load`)
    *   `pubspec.yaml` 파일에 에셋 경로가 등록되어 있어야 합니다.

## 동작 방식

1.  **WebRTC 연결**: `SignalingService`를 통해 WebRTC 연결을 설정하고 상대방의 비디오 스트림을 수신하여 `RTCVideoView`(`_remoteRenderer`)에 표시합니다.
2.  **프레임 캡처**: `VideoCallScreen`의 `RepaintBoundary`(`_remoteBoundaryKey`)가 `RTCVideoView`를 감싸고 있습니다. `WebRTCFaceDetection` 서비스는 주기적으로(`Timer.periodic`) 이 `RepaintBoundary`의 `toImage()`를 호출하여 현재 화면에 보이는 상대방 비디오 프레임을 `ui.Image`로 캡처합니다.
3.  **이미지 처리 및 저장**: 캡처된 `ui.Image`는 PNG 형식의 `ByteData`로 변환된 후, `path_provider`를 이용해 기기의 임시 저장 공간에 파일로 저장됩니다.
4.  **얼굴 감지**: 저장된 이미지 파일의 경로를 사용하여 `InputImage.fromFilePath()`로 ML Kit `InputImage`를 생성합니다. `_faceDetector.processImage()`를 호출하여 이미지 내에서 얼굴들을 감지하고, 각 얼굴의 `boundingBox` 정보를 얻습니다.
5.  **결과 스트리밍**: 감지된 얼굴 목록(`List<Face>`)과 캡처된 원본 프레임(`ui.Image`)은 각각 `StreamController` (`_facesController`, `_boundaryImageCtrl`)를 통해 `VideoCallScreen`으로 전달됩니다.
6.  **마스크 로딩**: `FaceMaskOverlay` 위젯은 `initState`에서 `maskAssetPath`에 지정된 경로의 마스크 이미지를 `rootBundle.load`를 통해 로드하여 `ui.Image` 객체(`_maskImage`)로 변환합니다.
7.  **마스크 오버레이**: `VideoCallScreen`은 `StreamBuilder` 또는 `setState`를 통해 업데이트된 얼굴 목록(`_detectedFaces`)과 캡처된 프레임(`_capturedBoundaryImage`)을 `FaceMaskOverlay` 위젯에 전달합니다.
8.  **렌더링**: `FaceMaskOverlay` 내부의 `CustomPaint` 위젯(`_FaceMaskPainter`)은 전달받은 `_capturedBoundaryImage`를 먼저 그리고, 그 위에 `_detectedFaces` 목록을 순회하며 각 얼굴의 `boundingBox` 위치에 맞춰 로드된 `_maskImage`를 덧그립니다. 좌표 변환은 `boundingBox`의 좌표를 `CustomPaint` 위젯의 크기에 비례하도록 계산하여 적용합니다.

## 주요 컴포넌트

*   **`VideoCallScreen`**: 영상 통화 UI, WebRTC 렌더러, `RepaintBoundary`, `FaceMaskOverlay` 위젯을 포함하고 상태를 관리합니다.
*   **`WebRTCFaceDetection`**: `RepaintBoundary`로부터 프레임을 캡처하고, ML Kit를 사용하여 얼굴을 감지하며, 결과를 스트림으로 제공하는 서비스 클래스입니다.
*   **`FaceMaskOverlay`**: 캡처된 비디오 프레임과 감지된 얼굴 목록을 입력받아 `CustomPaint`를 통해 마스크를 그리는 위젯입니다.
*   **`_FaceMaskPainter`**: `CustomPaint`의 실제 로직을 담당하며, 비디오 프레임과 마스크 이미지를 캔버스에 그립니다.

## 설정

*   **권한**: 영상 통화 및 얼굴 인식을 위해 카메라, 마이크 권한이 필요합니다. (`permission_handler` 사용)
*   **에셋**: 사용할 마스크 이미지를 `assets` 폴더 (예: `assets/images/`)에 추가하고, `pubspec.yaml` 파일의 `flutter > assets` 섹션에 해당 경로를 등록해야 합니다. 