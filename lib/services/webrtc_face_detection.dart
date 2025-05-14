import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:image/image.dart' as img; // PNG 인코딩(옵션) 시
import 'dart:ui' as ui;
import 'package:path_provider/path_provider.dart'; // 터미널에서 설치 필요

class WebRTCFaceDetection {
  final FaceDetector _faceDetector;
  final _facesController = StreamController<List<Face>>.broadcast();
  Stream<List<Face>> get facesStream => _facesController.stream;

  final _boundaryImageCtrl = StreamController<ui.Image>.broadcast();
  Stream<ui.Image> get boundaryImageStream => _boundaryImageCtrl.stream;

  Timer? _captureTimer;
  GlobalKey? _boundaryKey;
  bool _isDetecting = false;

  WebRTCFaceDetection()
    : _faceDetector = FaceDetector(
        options: FaceDetectorOptions(
          enableTracking: false,
          enableClassification: true,
          enableLandmarks: true,
          enableContours: false,
          performanceMode: FaceDetectorMode.accurate,
        ),
      );

  void attachBoundary(
    GlobalKey boundaryKey, {
    Duration interval = const Duration(milliseconds: 500),
  }) {
    _boundaryKey = boundaryKey;
    _captureTimer = Timer.periodic(
      interval,
      (_) => _captureFrameFromBoundary(),
    );
  }

  Future<void> _captureFrameFromBoundary() async {
    if (_isDetecting) {
      // print('[WebRTCFaceDetection] 이미 감지 중입니다. 캡처를 건너뜁니다.');
      return;
    }
    if (_boundaryKey == null) {
      print('[WebRTCFaceDetection] boundaryKey가 null입니다.');
      return;
    }

    try {
      _isDetecting = true;
      // print('[WebRTCFaceDetection] 캡처 시작');

      final boundaryObject =
          _boundaryKey!.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundaryObject == null) {
        print('[WebRTCFaceDetection] RepaintBoundary 객체를 찾지 못했습니다.');
        return;
      }

      final ui.Image boundaryImage = await boundaryObject.toImage();
      final ByteData? byteData = await boundaryImage.toByteData(
        format: ui.ImageByteFormat.png,
      );
      if (byteData == null) {
        // print('[WebRTCFaceDetection] toByteData 변환 실패');
        return;
      }

      // print(
      //   '[WebRTCFaceDetection] boundaryImage 캡처 성공: '
      //   'width=${boundaryImage.width}, height=${boundaryImage.height}',
      // );

      // 1) PNG 바이트를 임시 파일로 저장
      final pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/default_mask.png';
      final file = File(filePath);
      await file.writeAsBytes(pngBytes);

      // 2) 임시 파일 경로로부터 InputImage 생성
      final inputImage = InputImage.fromFilePath(filePath);

      // 3) 얼굴 감지 수행
      final faces = await _faceDetector.processImage(inputImage);
      // print('[WebRTCFaceDetection] 감지된 얼굴 개수: ${faces.length}');

      // 4) 결과 스트림
      _facesController.add(faces);
      _boundaryImageCtrl.add(boundaryImage);
    } catch (e) {
      // print('[WebRTCFaceDetection] 에러 발생: $e');
    } finally {
      _isDetecting = false;
      // print('[WebRTCFaceDetection] 캡처 종료');
    }
  }

  Future<void> dispose() async {
    _captureTimer?.cancel();
    if (!_facesController.isClosed) _facesController.close();
    if (!_boundaryImageCtrl.isClosed) _boundaryImageCtrl.close();
    await _faceDetector.close();
  }

  // attachRenderer는 사용하지 않는다면 빈 메서드로 둡니다.
  void attachRenderer(RTCVideoRenderer remoteRenderer) {}
}
