import 'dart:io';
import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

/// 얼굴 마스킹을 담당하는 위젯
/// - ML Kit FaceDetector로 얼굴을 분석한 뒤,
///   마커(또는 이미지)를 얼굴 위에 그리는 예시입니다.
class FaceMaskOverlay extends StatefulWidget {
  // 카메라(혹은 프레임)에서 이미지 바이트를 받아 표시하는 예시 (Raw image bytes)
  final ui.Image? cameraImage;
  final List<Face> faces; // 이미 감지된 얼굴 목록
  final String maskAssetPath;

  const FaceMaskOverlay({
    Key? key,
    required this.cameraImage,
    required this.faces,
    this.maskAssetPath = 'assets/images/default_mask.png',
  }) : super(key: key);

  @override
  State<FaceMaskOverlay> createState() => _FaceMaskOverlayState();
}

class _FaceMaskOverlayState extends State<FaceMaskOverlay> {
  ui.Image? _maskImage;

  @override
  void initState() {
    super.initState();
    _loadMaskImage();
  }

  Future<void> _loadMaskImage() async {
    final data = await rootBundle.load(widget.maskAssetPath);
    final list = data.buffer.asUint8List();
    final image = await decodeImageFromList(list);
    setState(() {
      _maskImage = image;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cameraImage == null) {
      print('[FaceMaskOverlay] cameraImage가 null입니다. 아직 캡처된 ui.Image가 없어요.');
    }
    if (_maskImage == null) {
      print('[FaceMaskOverlay] _maskImage가 null입니다. 마스크 에셋을 아직 못 불러왔습니다.');
    }

    if (widget.cameraImage == null || _maskImage == null) {
      // 아직 이미지 로딩 전이면, 빈 컨테이너 표시
      return const SizedBox.shrink();
    }
    return CustomPaint(
      painter: _FaceMaskPainter(
        image: widget.cameraImage!,
        mask: _maskImage!,
        faces: widget.faces,
      ),
      child: Container(),
    );
  }
}

/// 실제로 얼굴 위에 마스크 이미지를 그리는 Painter
class _FaceMaskPainter extends CustomPainter {
  final ui.Image image; // 카메라 프레임(렌더링할 원본)
  final ui.Image mask; // 얼굴에 씌울 이미지
  final List<Face> faces;

  _FaceMaskPainter({
    required this.image,
    required this.mask,
    required this.faces,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 원본 카메라 프레임을 그리기
    final paint = Paint();
    // 화면 크기에 맞춰 이미지 스케일 조정
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(0, 0, size.width, size.height);
    canvas.drawImageRect(image, srcRect, dstRect, paint);

    // 얼굴마다 마스크 이미지 오버레이
    for (final face in faces) {
      // 얼굴 boundingBox
      final boundingBox = face.boundingBox;

      // 예: 얼굴 boundingBox에 맞게 mask 이미지를 스케일링
      final maskWidth = boundingBox.width;
      final maskHeight = boundingBox.height;

      // 화면 좌표 변환 (카메라 → 위젯 사이즈) 필요할 수 있음
      // 여기서는 단순히 boundingBox 위치가 그대로 그려진다고 가정
      final left = boundingBox.left * (size.width / image.width);
      final top = boundingBox.top * (size.height / image.height);
      final right = left + maskWidth * (size.width / image.width);
      final bottom = top + maskHeight * (size.height / image.height);

      final maskRect = Rect.fromLTRB(left, top, right, bottom);

      // 마스크 그리기: mask를 maskRect에 맞춰서 그린다.
      canvas.drawImageRect(
        mask,
        Rect.fromLTWH(0, 0, mask.width.toDouble(), mask.height.toDouble()),
        maskRect,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FaceMaskPainter oldDelegate) =>
      oldDelegate.image != image ||
      oldDelegate.mask != mask ||
      oldDelegate.faces != faces;
}
