import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../video_call/video_call_screen.dart';
import '../analysis/analysis_screen.dart';
import '../prediction/prediction_screen.dart';
import '../date_recommendation/date_recommendation_screen.dart';
import '../chat/chat_screen.dart';
import '../settings/settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const MainHomePage(),
    const DateRecommendationScreen(),
    const ChatScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('다온'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AnalysisScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.psychology_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const PredictionScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: '홈'),
          BottomNavigationBarItem(icon: Icon(Icons.place), label: '데이트 장소'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: '채팅',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '설정'),
        ],
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }
}

class MainHomePage extends StatelessWidget {
  const MainHomePage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 20),
          // 상단 텍스트
          const Text(
            '랜덤 소개팅 시작하기',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '얼굴을 가린 상태에서 대화를 시작해보세요',
            style: TextStyle(fontSize: 14, color: AppColors.darkGrey),
          ),
          const SizedBox(height: 40),

          // 연결 아이콘
          Container(
            width: 150,
            height: 150,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFFCC84FF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: const Icon(Icons.video_call, size: 70, color: Colors.white),
          ),

          const SizedBox(height: 40),

          // 연결 버튼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: CustomButton(
              text: '상대방과 연결하기',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const VideoCallScreen(),
                  ),
                );
              },
              icon: Icons.videocam,
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
