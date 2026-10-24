import 'package:capstone_porj/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main/main_screen.dart';
import '../../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  String? _errorMessage;

  Future<void> _handleLogin() async {
    try {
      final error = await AuthService.login(
        _idController.text.trim(),
        _pwController.text.trim(),
      );
      if (error == null) {
        // Provider 등 상태관리 갱신 필요시 여기에 추가
        // 예: UserProvider.of(context, listen: false).setUserId(새로운 userId);

        // 앱 스택을 모두 지우고 메인페이지로 이동 (새로고침 효과)
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
          (route) => false,
        );
      } else {
        // 에러 처리
        setState(() {
          _errorMessage = error;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

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
              CustomTextField(
                controller: _idController,
                hintText: '아이디',
                prefixIcon: const Icon(Icons.person_outline),
              ),

              const SizedBox(height: 16),

              // 비밀번호 입력 필드
              CustomTextField(
                controller: _pwController,
                hintText: '비밀번호',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
              ),

              const SizedBox(height: 40),

              // 로그인 버튼
              CustomButton(text: '로그인', onPressed: _handleLogin),

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
