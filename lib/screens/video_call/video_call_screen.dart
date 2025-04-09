import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';

class VideoCallScreen extends StatelessWidget {
  const VideoCallScreen({Key? key}) : super(key: key);

  void _showCallEndDialog(BuildContext context) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // 상대방 비디오 화면 (전체 화면)
            Container(
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
                  color: Colors.grey[800],
                  border: Border.all(color: Colors.white, width: 2),
                ),
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
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                  ],
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
                    icon: const Icon(
                      Icons.mic_off,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {},
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
                      onPressed: () => _showCallEndDialog(context),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.switch_camera,
                      color: Colors.white,
                      size: 30,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
