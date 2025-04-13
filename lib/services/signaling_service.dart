import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:flutter_webrtc/flutter_webrtc.dart';

class SignalingService {
  // 싱글톤 패턴
  static final SignalingService _instance = SignalingService._internal();
  factory SignalingService() => _instance;
  SignalingService._internal();

  // Socket.io 클라이언트
  IO.Socket? socket;

  // WebRTC 연결 관련 변수
  Map<String, dynamic> configuration = {
    'iceServers': [
      {'urls': 'stun:stun.l.google.com:19302'},
      {'urls': 'stun:stun1.l.google.com:19302'},
      {'urls': 'stun:stun2.l.google.com:19302'},
    ],
  };

  RTCPeerConnection? peerConnection;
  MediaStream? localStream;
  MediaStream? remoteStream;
  String? currentRoomId;

  // 상태 업데이트 콜백
  Function(RTCPeerConnectionState)? onConnectionStateChange;
  Function(MediaStream)? onLocalStream;
  Function(MediaStream)? onRemoteStream;
  Function(String)? onCallEnded;
  Function(String)? onIncomingCall;

  // 연결 상태
  bool get isConnected => socket?.connected ?? false;

  // 임시 offer 저장 변수 추가
  RTCSessionDescription? pendingOffer;

  // 소켓 서버에 연결
  Future<void> connect(String serverUrl) async {
    socket = IO.io(
      serverUrl,
      IO.OptionBuilder()
          .setTransports(['websocket'])
          .disableAutoConnect()
          .build(),
    );

    socket?.connect();

    socket?.on('connect', (_) {
      print('소켓 서버에 연결됨');
      // 연결 후 사용자 등록 (기기 ID나 사용자 ID 사용)
      socket?.emit('register', socket?.id);
    });

    socket?.on('disconnect', (_) {
      print('소켓 서버 연결 끊김');
    });

    socket?.on('incomingCall', (data) async {
      print('수신 통화: $data');
      pendingOffer = RTCSessionDescription(
        data['offer']['sdp'],
        data['offer']['type'],
      );
      if (onIncomingCall != null) {
        onIncomingCall!(data['caller']);
      }

      // 통화를 자동으로 수락할 경우:
      // await _handleIncomingCall(data);
    });

    socket?.on('callAnswered', (data) async {
      print('통화 수락됨: $data');
      await _setRemoteDescription(data['answer']);
    });

    socket?.on('ice-candidate', (data) async {
      print('ICE 후보 수신: $data');
      await _addIceCandidate(data['candidate']);
    });

    socket?.on('callEnded', (data) {
      print('통화 종료됨: $data');
      endCall();
      if (onCallEnded != null) {
        onCallEnded!(data['caller']);
      }
    });
  }

  // 연결 해제
  void disconnect() {
    socket?.disconnect();
  }

  // 로컬 미디어 스트림 생성
  Future<MediaStream> createLocalStream() async {
    final Map<String, dynamic> mediaConstraints = {
      'audio': true,
      'video': {
        'mandatory': {
          'minWidth': '640',
          'minHeight': '480',
          'minFrameRate': '30',
        },
        'facingMode': 'user',
        'optional': [],
      },
    };

    try {
      localStream = await navigator.mediaDevices.getUserMedia(mediaConstraints);
      if (onLocalStream != null) {
        onLocalStream!(localStream!);
      }
      return localStream!;
    } catch (e) {
      print('미디어 스트림 생성 오류: $e');
      rethrow;
    }
  }

  // 통화 시작
  Future<void> startCall(String targetId) async {
    try {
      // 피어 연결 생성
      peerConnection = await createPeerConnection(configuration);

      // 로컬 스트림이 없으면 생성
      localStream ??= await createLocalStream();

      // 로컬 스트림의 모든 트랙을 피어 연결에 추가
      localStream!.getTracks().forEach((track) {
        peerConnection!.addTrack(track, localStream!);
      });

      // 원격 스트림 이벤트 처리
      peerConnection!.onTrack = (RTCTrackEvent event) {
        print('원격 트랙 추가됨');
        if (event.streams.isNotEmpty) {
          remoteStream = event.streams[0];
          if (onRemoteStream != null) {
            onRemoteStream!(remoteStream!);
          }
        }
      };

      // ICE 후보 생성 이벤트 처리
      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('로컬 ICE 후보 생성됨');
        socket?.emit('ice-candidate', {
          'target': targetId,
          'candidate': candidate.toMap(),
        });
      };

      // 연결 상태 변경 이벤트 처리
      peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('피어 연결 상태: $state');
        if (onConnectionStateChange != null) {
          onConnectionStateChange!(state);
        }
      };

      // 제안 생성
      RTCSessionDescription offer = await peerConnection!.createOffer();
      await peerConnection!.setLocalDescription(offer);

      // 대상에게 통화 요청 전송
      socket?.emit('call', {'target': targetId, 'offer': offer.toMap()});

      currentRoomId = targetId;
    } catch (e) {
      print('통화 시작 오류: $e');
      await _cleanUp();
      rethrow;
    }
  }

  // 통화 수락
  Future<void> answerCall(String callerId) async {
    try {
      print('통화 수락 시작: $callerId');

      // 1. PeerConnection 초기화 확인
      if (peerConnection == null) {
        await _createPeerConnection();
        print('PeerConnection 생성됨');
      }

      // 2. 원격 설명 설정 (순서 중요)
      if (pendingOffer == null) {
        throw Exception('수신된 offer가 없습니다.');
      }
      await peerConnection!.setRemoteDescription(pendingOffer!);
      print('원격 설명 설정됨');

      // 3. 로컬 스트림이 없으면 생성
      if (localStream == null) {
        await createLocalStream();
        print('로컬 스트림 생성됨');
      }

      // 4. 로컬 스트림 추가
      localStream!.getTracks().forEach((track) {
        peerConnection!.addTrack(track, localStream!);
      });
      print('로컬 트랙 추가됨');

      // 5. 응답 생성
      final answer = await peerConnection!.createAnswer();
      print('응답 생성됨');

      // 6. 로컬 설명 설정
      await peerConnection!.setLocalDescription(answer);
      print('로컬 설명 설정됨');

      // 7. 응답 전송
      socket?.emit('callAnswered', {
        'caller': callerId,
        'answer': answer.toMap(),
      });
      print('응답 전송됨: $callerId');
    } catch (e) {
      print('통화 수락 중 오류 발생: $e');
      // 오류 발생 시 연결 정리
      _cleanupPeerConnection();
      rethrow;
    }
  }

  // PeerConnection 정리 메서드 추가
  void _cleanupPeerConnection() {
    try {
      peerConnection?.close();
      peerConnection = null;
      print('PeerConnection 정리됨');
    } catch (e) {
      print('PeerConnection 정리 중 오류: $e');
    }
  }

  // 통화 종료
  Future<void> endCall() async {
    if (currentRoomId != null) {
      socket?.emit('endCall', {'target': currentRoomId});
    }

    await _cleanUp();
  }

  // 원격 설명 설정
  Future<void> _setRemoteDescription(dynamic answer) async {
    try {
      RTCSessionDescription description = RTCSessionDescription(
        answer['sdp'],
        answer['type'],
      );
      await peerConnection?.setRemoteDescription(description);
    } catch (e) {
      print('원격 설명 설정 오류: $e');
    }
  }

  // ICE 후보 추가
  Future<void> _addIceCandidate(dynamic candidate) async {
    try {
      await peerConnection?.addCandidate(
        RTCIceCandidate(
          candidate['candidate'],
          candidate['sdpMid'],
          candidate['sdpMLineIndex'],
        ),
      );
    } catch (e) {
      print('ICE 후보 추가 오류: $e');
    }
  }

  // 들어오는 통화 처리
  Future<void> _handleIncomingCall(dynamic data) async {
    try {
      await answerCall(data['caller']);
    } catch (e) {
      print('들어오는 통화 처리 오류: $e');
    }
  }

  // 자원 정리
  Future<void> _cleanUp() async {
    try {
      await peerConnection?.close();
      peerConnection = null;

      localStream?.getTracks()?.forEach((track) => track.stop());
      localStream = null;

      remoteStream?.getTracks()?.forEach((track) => track.stop());
      remoteStream = null;

      currentRoomId = null;
    } catch (e) {
      print('정리 오류: $e');
    }
  }

  // 카메라 전환
  Future<void> switchCamera() async {
    if (localStream != null) {
      final videoTrack = localStream!.getVideoTracks()[0];
      await Helper.switchCamera(videoTrack);
    }
  }

  // 마이크 음소거 전환
  Future<void> toggleMic() async {
    if (localStream != null) {
      final audioTrack = localStream!.getAudioTracks()[0];
      audioTrack.enabled = !audioTrack.enabled;
    }
  }

  // _createPeerConnection 메서드 추가
  Future<void> _createPeerConnection() async {
    try {
      final Map<String, dynamic> configuration = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
          {'urls': 'stun:stun1.l.google.com:19302'},
        ],
      };

      peerConnection = await createPeerConnection(configuration);

      // 원격 스트림 이벤트 처리
      peerConnection!.onTrack = (RTCTrackEvent event) {
        print('원격 트랙 추가됨');
        if (event.streams.isNotEmpty) {
          remoteStream = event.streams[0];
          if (onRemoteStream != null) {
            onRemoteStream!(remoteStream!);
          }
        }
      };

      // ICE 후보 생성 이벤트 처리
      peerConnection!.onIceCandidate = (RTCIceCandidate candidate) {
        print('로컬 ICE 후보 생성됨');
        if (currentRoomId != null) {
          socket?.emit('ice-candidate', {
            'target': currentRoomId,
            'candidate': candidate.toMap(),
          });
        }
      };

      // 연결 상태 변경 이벤트 처리
      peerConnection!.onConnectionState = (RTCPeerConnectionState state) {
        print('피어 연결 상태: $state');
        if (onConnectionStateChange != null) {
          onConnectionStateChange!(state);
        }
      };
    } catch (e) {
      print('PeerConnection 생성 오류: $e');
      rethrow;
    }
  }

  // 통화 거절 메서드 추가
  void rejectCall(String callerId) {
    print('통화 거절: $callerId');
    socket?.emit('callRejected', {'caller': callerId});
  }

  // 통화 수락 메서드 수정
  Future<void> acceptCall(String callerId) async {
    try {
      print('통화 수락 요청: $callerId');
      currentRoomId = callerId;

      // 수락 의사를 서버에 전달
      socket?.emit('acceptCall', {'caller': callerId});

      // 실제 통화 연결 설정
      await answerCall(callerId);
    } catch (e) {
      print('통화 수락 오류: $e');
      rethrow;
    }
  }
}
