import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import '../../constants/app_colors.dart';
import '../../services/signaling_service.dart';
import '../../services/permission_service.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:async';

class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({Key? key}) : super(key: key);

  @override
  State<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  final SignalingService _signalingService = SignalingService();

  final _localRenderer = RTCVideoRenderer();
  final _remoteRenderer = RTCVideoRenderer();

  bool _isMicMuted = false;
  bool _isConnecting = false;
  bool _isInCall = false;
  bool _hasError = false;
  String _errorMessage = '';
  String? _remoteUserId;

  // 상태 확인 타이머 추가
  Timer? _connectionCheckTimer;

  @override
  void initState() {
    super.initState();
    _initRenderers();
    _setupSignaling();
    _connectToServer();

    // 연결 상태 주기적 확인
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkConnectionState();
    });
  }

  @override
  void dispose() {
    _connectionCheckTimer?.cancel();
    _localRenderer.dispose();
    _remoteRenderer.dispose();
    _signalingService.endCall();
    super.dispose();
  }

  // 렌더러 초기화
  Future<void> _initRenderers() async {
    await _localRenderer.initialize();
    await _remoteRenderer.initialize();
  }

  // 시그널링 설정
  void _setupSignaling() {
    _signalingService.onLocalStream = (stream) {
      setState(() {
        _localRenderer.srcObject = stream;
      });
    };

    _signalingService.onRemoteStream = (stream) {
      setState(() {
        _remoteRenderer.srcObject = stream;
        _isInCall = true;
        _isConnecting = false;
      });
    };

    _signalingService.onConnectionStateChange = (state) {
      print('연결 상태 변경: $state');
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        setState(() {
          _isInCall = false;
          _isConnecting = false;
        });
      }
    };

    _signalingService.onCallEnded = (callerId) {
      setState(() {
        _isInCall = false;
        _isConnecting = false;
        _remoteUserId = null;
      });
      _showCallEndDialog();
    };

    _signalingService.onIncomingCall = (callerId) {
      setState(() {
        _remoteUserId = callerId;
      });
      _showIncomingCallDialog(callerId);
    };
  }

  // 서버 연결
  Future<void> _connectToServer() async {
    try {
      // 권한 요청
      bool hasPermission =
          await PermissionService.requestVideoCallPermissions();
      if (!hasPermission) {
        setState(() {
          _hasError = true;
          _errorMessage = '카메라 및 마이크 권한이 필요합니다.';
        });
        return;
      }

      // Socket.IO 서버에 연결 (서버 주소를 실제 주소로 변경)
      await _signalingService.connect('http://195.109.1.137:5000');

      // 로컬 스트림 생성
      await _signalingService.createLocalStream();

      setState(() {
        _isConnecting = true;
      });

      // 연결 시작
      // 실제 구현에서는 여기서 매칭 서버에 요청을 보내 매칭된 사용자 ID를 받아와야 함
      // 지금은 단순화를 위해 바로 연결 시작
      final response = await _requestMatching();
      if (response != null && response['matchedUserId'] != null) {
        String targetId = response['matchedUserId'];
        print('매칭된 사용자: $targetId');

        setState(() {
          _remoteUserId = targetId;
        });

        await _signalingService.startCall(targetId);
      } else {
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = '매칭 가능한 사용자가 없습니다.';
        });
      }
    } catch (e) {
      print('연결 오류: $e');
      setState(() {
        _isConnecting = false;
        _hasError = true;
        _errorMessage = '연결 중 오류가 발생했습니다: $e';
      });
    }
  }

  // 사용자 매칭 요청 (실제 매칭 서버와 통신)
  Future<Map<String, dynamic>?> _requestMatching() async {
    // 소켓 ID가 없으면 반환
    if (_signalingService.socket?.id == null) {
      setState(() {
        _hasError = true;
        _errorMessage = '서버에 연결되지 않았습니다.';
      });
      return null;
    }

    // 실제 매칭 서비스 호출
    try {
      final socketId = _signalingService.socket!.id;
      final response = await http
          .get(Uri.parse('http://195.109.1.137:5000/match?userId=$socketId'))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        // 매칭 가능한 사용자가 없음
        setState(() {
          _isConnecting = false;
          _hasError = true;
          _errorMessage = '매칭 가능한 사용자가 없습니다. 잠시 후 다시 시도하세요.';
        });
        return null;
      } else {
        throw Exception('매칭 요청 실패: ${response.statusCode}');
      }
    } catch (e) {
      print('매칭 오류: $e');
      setState(() {
        _hasError = true;
        _errorMessage = '매칭 중 오류가 발생했습니다: $e';
      });
      return null;
    }
  }

  // 통화 종료 다이얼로그
  void _showCallEndDialog() {
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
                  Navigator.pop(context); // 이전 화면으로 돌아가기
                },
              ),
            ],
          ),
    );
  }

  // 수신 통화 다이얼로그
  void _showIncomingCallDialog(String callerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          title: const Text('수신 통화'),
          content: Text('$callerId님으로부터 통화 요청이 왔습니다.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _isConnecting = false;
                  _remoteUserId = null;
                });
                _signalingService.rejectCall(callerId);
              },
              child: const Text('거절'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                setState(() {
                  _isConnecting = true;
                });

                try {
                  // 통화 수락 후 처리
                  await _signalingService.acceptCall(callerId);
                  setState(() {
                    _isInCall = true;
                    _isConnecting = false;
                  });
                  print('통화가 성공적으로 연결되었습니다');
                } catch (e) {
                  print('통화 연결 중 오류 발생: $e');
                  setState(() {
                    _isConnecting = false;
                    _hasError = true;
                    _errorMessage = '통화 연결 중 오류가 발생했습니다: $e';
                  });
                }
              },
              child: const Text('수락'),
            ),
          ],
        );
      },
    );
  }

  // 마이크 토글
  void _toggleMic() {
    _signalingService.toggleMic();
    setState(() {
      _isMicMuted = !_isMicMuted;
    });
  }

  // 카메라 전환
  void _switchCamera() {
    _signalingService.switchCamera();
  }

  // 통화 종료
  void _endCall() {
    _signalingService.endCall();
    _showCallEndDialog();
  }

  // 오류 다이얼로그
  void _showErrorDialog(String message) {
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
                        onPressed: _endCall,
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
                      onPressed: _endCall,
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
              setState(() {
                _hasError = false;
                _errorMessage = '';
              });
              _connectToServer(); // 다시 연결 시도
            },
            child: const Text('다시 시도'),
          ),
        ],
      ),
    );
  }
}
