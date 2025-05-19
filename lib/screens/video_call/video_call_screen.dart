import 'package:capstone_porj/models/call_result_data.dart';
import 'package:capstone_porj/widgets/face_mask_overlay.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../constants/app_colors.dart';
import '../../services/signaling_service.dart';
import '../../services/permission_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../../services/webrtc_face_detection.dart';
import 'dart:ui' as ui; // toImage() 사용을 위해 추가 (이미 있다면 생략)
import 'package:capstone_porj/config/app_config.dart';
import '../../services/recorder_service.dart';
import '../../services/clova_speech_service.dart';
import 'dart:io';
import 'package:capstone_porj/services/openai_service.dart';
import 'package:capstone_porj/services/analysis_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_porj/screens/video_call/loading_screen.dart';
import 'package:capstone_porj/services/auth_service.dart';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({Key? key}) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final SignalingService _signalingService = SignalingService();

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  // 추가: WebRTCFaceDetection
  late final WebRTCFaceDetection _webrtcFaceDetection;

  List<Face> _detectedFaces = [];

  bool _isMicMuted = false;
  bool _isConnecting = false;
  bool _isInCall = false;
  bool _hasError = false;
  String _errorMessage = '';
  String? _remoteUserId;

  // 상태 확인 타이머 추가
  Timer? _connectionCheckTimer;

  // RepaintBoundary용 GlobalKey 추가
  final GlobalKey _remoteBoundaryKey = GlobalKey();

  ui.Image? _capturedBoundaryImage; // 추가

  // 1. 서비스 인스턴스 선언
  final RecorderService _recorderService = RecorderService();
  final ClovaSpeechService _clovaSpeechService = ClovaSpeechService();

  @override
  void initState() {
    super.initState();
    print('[VideoCallScreen] initState 시작');
    _initRenderers();
    _setupSignaling();
    _connectToServer(); // 서버 연결 및 매칭 시작

    // 연결 상태 주기적 확인 (디버깅용)
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      // _checkConnectionState(); // 필요시에만 활성화
    });

    // ML Kit + WebRTC FaceDetection 초기화
    _webrtcFaceDetection = WebRTCFaceDetection();

    // RepaintBoundary attach 하기
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        // 위젯이 마운트된 상태인지 확인
        _webrtcFaceDetection.attachBoundary(_remoteBoundaryKey);
      }
    });

    // boundaryImageStream 구독
    _webrtcFaceDetection.boundaryImageStream.listen((ui.Image image) {
      if (mounted) {
        // 위젯이 마운트된 상태인지 확인
        setState(() {
          _capturedBoundaryImage = image;
        });
      }
    });

    _recorderService.init();
    _recorderService.startRecording(); // 통화 시작 시 녹음 시작

    _signalingService.onCallEnded = (_) => _onRemoteCallEnded();

    print('[VideoCallScreen] initState 완료');
  }

  @override
  void dispose() {
    print('[VideoCallScreen] dispose 시작');
    _connectionCheckTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _webrtcFaceDetection.dispose();

    // SignalingService의 자원 정리 및 연결 해제
    _signalingService.cleanUp();
    _signalingService.disconnect();

    _recorderService.dispose();

    print('[VideoCallScreen] dispose 완료');
    super.dispose();
  }

  // 렌더러 초기화
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();

    // remoteRenderer를 MLKit faceDetection에 연결
    _webrtcFaceDetection.attachRenderer(_remoteRenderer);
    // facesStream 구독
    _webrtcFaceDetection.facesStream.listen((faces) {
      if (mounted) {
        setState(() {
          _detectedFaces = faces;
        });
      }
    });
  }

  // 시그널링 설정
  void _setupSignaling() {
    _signalingService.onLocalStream = (stream) {
      if (mounted) {
        setState(() {
          _localRenderer.srcObject = stream;
        });
      }
    };

    _signalingService.onRemoteStream = (stream) {
      if (mounted) {
        setState(() {
          _remoteRenderer.srcObject = stream;
          _isInCall = true;
          _isConnecting = false;
        });
      }
    };

    _signalingService.onConnectionStateChange = (state) {
      print('연결 상태 변경: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (mounted) {
          setState(() {
            _isInCall = false;
            _isConnecting = false;
          });
        }
      }
    };

    _signalingService.onIncomingCall = (callerId) async {
      if (mounted) {
        setState(() {
          _remoteUserId = callerId;
        });
      }

      // 수신 알림 다이얼로그를 띄우는 대신, 자동으로 통화 수락
      try {
        print('수신 통화 자동 수락 시도: $callerId');
        await _signalingService.acceptCall(callerId);
        if (mounted) {
          setState(() {
            _isInCall = true;
            _isConnecting = false;
          });
        }
      } catch (e) {
        print('수신 통화 자동 수락 중 오류: $e');
        if (mounted) {
          setState(() {
            _isConnecting = false;
            _hasError = true;
            _errorMessage = '수신 통화 자동 수락 오류: $e';
          });
        }
      }
    };
  }

  // 서버 연결
  Future<void> _connectToServer() async {
    try {
      // 권한 요청
      bool hasPermission =
          await PermissionService.requestVideoCallPermissions();
      if (!hasPermission) {
        if (mounted) {
          setState(() {
            _hasError = true;
            _errorMessage = '카메라 및 마이크 권한이 필요합니다.';
          });
        }
        return;
      }

      // Socket.IO 서버에 연결 - AppConfig 사용
      await _signalingService.connect(AppConfig.serverUrl);

      // 로컬 스트림 생성
      await _signalingService.createLocalStream();

      if (mounted) {
        setState(() {
          _isConnecting = true; // 로딩 화면 표시
        });
      }

      // 매칭 시도 - 성공할 때까지 대기
      final response = await _requestMatchingUntilFound();
      if (response != null && response['matchedUserId'] != null) {
        final targetId = response['matchedUserId'].toString();
        print('매칭된 사용자: $targetId');

        setState(() {
          _remoteUserId = targetId;
        });

        // 내 userId 가져오기
        final prefs = await SharedPreferences.getInstance();
        final myUserId = prefs.getInt('user_id');
        if (myUserId == null) {
          setState(() {
            _hasError = true;
            _errorMessage = '내 userId를 찾을 수 없습니다.';
          });
          return;
        }

        // userId가 더 작은 쪽만 startCall 호출
        if (myUserId < int.parse(targetId)) {
          await _signalingService.startCall(myUserId, int.parse(targetId));
        }
        // userId가 더 큰 쪽은 incomingCall을 기다림

        // 연결 후 로딩 해제
        setState(() {
          _isConnecting = false;
        });
      }
    } catch (e) {
      print('연결 오류: $e');
      if (mounted) {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = '연결 중 오류가 발생했습니다: $e';
        });
      }
    }
  }

  // 매칭 서버에 무한 재시도하는 로직
  Future<Map<String, dynamic>?> _requestMatchingUntilFound() async {
    while (true) {
      try {
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getInt('user_id');
        print(
          '[VideoCallScreen] SharedPreferences에서 user_id로 userId 읽음: $userId',
        );
        if (userId == null) {
          throw Exception('userId가 없습니다.');
        }
        final response = await http
            .get(Uri.parse(AppConfig.getMatchingUrl(userId)))
            .timeout(const Duration(seconds: 10));

        // 3) 매칭 성공
        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
        // 4) 매칭 실패(404)일 경우 - 잠시 대기 후 재시도
        else if (response.statusCode == 404) {
          // 로그 출력은 필요하면 남겨두세요
          print('매칭 중... 아직 사용자가 없습니다. 잠시 후 재시도합니다.');
          await Future.delayed(const Duration(seconds: 3));
          continue;
        } else {
          // 그 외 상태코드는 즉시 예외
          throw Exception('매칭 요청 실패: ${response.statusCode}');
        }
      } catch (e) {
        // 네트워크 오류 등
        print('매칭 오류: $e');
        // 잠시 대기 후 다시 시도
        await Future.delayed(const Duration(seconds: 3));
      }
    }
  }

  // 통화 종료 다이얼로그
  void _showCallEndDialog() {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('통화가 종료되었습니다'),
              content: const Text('대화분석페이지와 예측페이지에 분석된 내용이 있습니다.'),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              actions: [
                TextButton(
                  child: const Text('확인'),
                  onPressed: () {
                    Navigator.pop(context); // 다이얼로그 닫기
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/main', (route) => false);
                  },
                ),
              ],
            ),
      );
    }
  }

  // 마이크 토글
  void _toggleMic() {
    _signalingService.toggleMic();
    if (mounted) {
      setState(() {
        _isMicMuted = !_isMicMuted;
      });
    }
  }

  // 카메라 전환
  void _switchCamera() {
    _signalingService.switchCamera();
  }

  // 통화내역 저장 함수
  Future<void> _saveCallHistoryToServer(
    String user_id,
    String partner_id,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('http://192.168.1.50:5000/api/call-history'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'user_id': user_id,
          'partner_id': partner_id,
          'date': DateTime.now().toIso8601String(),
        }),
      );
      if (response.statusCode != 200) {
        print('통화내역 서버 저장 실패: ${response.body}');
      }
    } catch (e) {
      print('통화내역 서버 저장 중 오류: $e');
    }
  }

  // 통화 종료
  Future<void> _endCall({bool auto = false}) async {
    if (!_isInCall) return;
    if (mounted) {
      setState(() {
        _isInCall = false;
      });
    }

    final filePath = await _recorderService.stopRecording();
    if (filePath == null) {
      if (mounted) {
        _showErrorDialog('녹음 파일이 존재하지 않습니다.');
      }
      return;
    }
    final file = File(filePath);
    final fileLength = await file.length();
    if (fileLength < 1000) {
      if (mounted) {
        _showErrorDialog('녹음 파일이 너무 짧거나 비어 있습니다.');
      }
      return;
    }

    // 내 userId 가져오기 (예시: SharedPreferences 등에서)
    final user_id = await AuthService.getUserId();
    final partner_id = _remoteUserId;
    if (user_id != null && partner_id != null) {
      await _saveCallHistoryToServer(user_id.toString(), partner_id.toString());
    }

    // 통화 종료 시점에 분석/예측 저장 화면으로 이동
    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => AnalysisScreen(
                audioFilePath: filePath,
                partnerName: _remoteUserId ?? '상대방',
              ),
        ),
      );
    }
  }

  // 오류 다이얼로그
  void _showErrorDialog(String message) {
    if (mounted) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('오류'),
              content: Text(message),
              actions: [
                TextButton(
                  child: const Text('확인'),
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
      );
    }
  }

  void _checkConnectionState() {
    if (_isInCall) {
      final connectionState = _signalingService.peerConnection?.connectionState;
      final iceConnectionState =
          _signalingService.peerConnection?.iceConnectionState;
      print(
        'WebRTC 연결 상태 확인: connectionState=$connectionState, iceConnectionState=$iceConnectionState',
      );

      // 원격 트랙 개수 확인
      final remoteStreams =
          _signalingService.peerConnection?.getRemoteStreams();
      print('원격 스트림: ${remoteStreams?.length ?? 0}개');

      if (remoteStreams != null && remoteStreams.isNotEmpty) {
        final tracks = remoteStreams[0]?.getTracks();
        print('원격 트랙: ${tracks?.length ?? 0}개');

        // 트랙이 활성화되어 있는지 확인
        if (tracks != null) {
          for (var track in tracks) {
            print('트랙 ID: ${track.id}, 활성화: ${track.enabled}');
          }
        }
      }
    }
  }

  void _onRemoteCallEnded() async {
    // 이미 통화가 종료된 경우 중복 실행 방지
    if (!_isInCall) return;
    await _endCall(auto: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
              // 상대방 비디오 화면 (전체 화면)
              _isInCall && _remoteRenderer.srcObject != null
                  ? RTCVideoView(
                    _remoteRenderer,
                    objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  )
                  : Container(
                    width: double.infinity,
                    height: double.infinity,
                    color: Colors.black87,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary.withOpacity(0.7),
                            ),
                            child: const Icon(
                              Icons.person,
                              size: 80,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          const Text(
                            '상대방',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

              // 자신의 비디오 화면 (오른쪽 상단 작은 화면)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  width: 120,
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child:
                        _localRenderer.srcObject != null
                            ? RTCVideoView(
                              _localRenderer,
                              mirror: true,
                              objectFit:
                                  RTCVideoViewObjectFit
                                      .RTCVideoViewObjectFitCover,
                            )
                            : Container(
                              color: Colors.grey[800],
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Colors.grey,
                                    ),
                                    child: const Icon(
                                      Icons.person,
                                      size: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  const Text(
                                    '나',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                  ),
                ),
              ),

              // 하단 컨트롤 버튼들
              Positioned(
                bottom: 40,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: Icon(
                        _isMicMuted ? Icons.mic_off : Icons.mic,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _toggleMic,
                    ),
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.red,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.withOpacity(0.3),
                            spreadRadius: 5,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.call_end,
                          color: Colors.white,
                          size: 30,
                        ),
                        onPressed: () => _endCall(auto: false),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.switch_camera,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: _switchCamera,
                    ),
                  ],
                ),
              ),

              // 화면 하단에 재시도 버튼 추가
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildErrorWidget(),
              ),
            ],
          ),
        ),
      );
    }

    if (_isConnecting && !_isInCall) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 20),
                const Text(
                  '상대방 연결 중...',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  child: const Text('취소'),
                  onPressed: () {
                    _signalingService.endCall();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 상대방 비디오 화면 (전체 화면)
          Positioned.fill(
            child: RepaintBoundary(
              key: _remoteBoundaryKey,
              child: RTCVideoView(_remoteRenderer),
            ),
          ),

          // FaceMaskOverlay에 cameraImage로 _capturedBoundaryImage 전달
          Positioned.fill(
            child: FaceMaskOverlay(
              cameraImage: _capturedBoundaryImage, // null 아님
              faces: _detectedFaces,
            ),
          ),

          // 자신의 비디오 화면 (오른쪽 상단 작은 화면)
          Positioned(
            top: 20,
            right: 20,
            child: Container(
              width: 120,
              height: 160,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child:
                    _localRenderer.srcObject != null
                        ? RTCVideoView(
                          _localRenderer,
                          mirror: true,
                          objectFit:
                              RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                        )
                        : Container(
                          color: Colors.grey[800],
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.grey,
                                ),
                                child: const Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                '나',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ),
              ),
            ),
          ),

          // 하단 컨트롤 버튼들
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(
                    _isMicMuted ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _toggleMic,
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.3),
                        spreadRadius: 5,
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.call_end,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () => _endCall(auto: false),
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.switch_camera,
                    color: Colors.white,
                    size: 30,
                  ),
                  onPressed: _switchCamera,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.red, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _hasError = false;
                  _errorMessage = '';
                });
              }
              _connectToServer(); // 다시 연결 시도
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
