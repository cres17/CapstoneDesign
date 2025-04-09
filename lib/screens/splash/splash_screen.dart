import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../auth/login_screen.dart';
import '../auth/signup_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, Color(0xFFCC84FF)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 로고 이미지
                Container(
                  width: 120,
                  height: 120,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      '다온',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // 로그인 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: CustomButton(
                    text: '로그인',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LoginScreen(),
                        ),
                      );
                    },
                    backgroundColor: Colors.white,
                    textColor: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 16),

                // 회원가입 버튼
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: CustomButton(
                    text: '회원가입',
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SignupScreen(),
                        ),
                      );
                    },
                    backgroundColor: Colors.transparent,
                    textColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),

                // 약관 동의 텍스트
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    '로그인을 하면 이용약관, 개인정보 처리방침, 쿠키 정책에 동의하게 됩니다.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
