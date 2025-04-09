import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main/main_screen.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로그인'), centerTitle: true, elevation: 0),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 30),

              // 앱 로고
              Center(
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                  ),
                  child: const Center(
                    child: Text(
                      '다온',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

              // 아이디 입력 필드
              const CustomTextField(
                hintText: '아이디',
                prefixIcon: Icon(Icons.person_outline),
              ),

              const SizedBox(height: 16),

              // 비밀번호 입력 필드
              const CustomTextField(
                hintText: '비밀번호',
                obscureText: true,
                prefixIcon: Icon(Icons.lock_outline),
              ),

              const SizedBox(height: 40),

              // 로그인 버튼
              CustomButton(
                text: '로그인',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                  );
                },
              ),

              const SizedBox(height: 16),

              // 소셜 로그인 버튼
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.facebook, color: Colors.blue),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(Icons.android, color: Colors.green),
                    onPressed: () {},
                  ),
                  const SizedBox(width: 20),
                  IconButton(
                    icon: const Icon(
                      Icons.phone_android,
                      color: AppColors.primary,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
