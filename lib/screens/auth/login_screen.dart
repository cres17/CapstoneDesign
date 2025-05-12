import 'package:flutter/material.dart';
import 'package:capstone_porj/services/auth_service.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main/main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();

  Future<void> _handleLogin() async {
    try {
      final result = await AuthService.login(
        _idController.text.trim(),
        _pwController.text.trim(),
      );

      // ✅ 로그인 성공 시 성별 추출
      final userGender = result['gender']?.toString();

      if (userGender != '남성' && userGender != '여성') {
        throw Exception('잘못된 성별 정보입니다: $userGender');
      }

      // 예측 화면에서는 영어로 변환해서 넘기기
      final modelGender = (userGender == '남성') ? 'male' : 'female';

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(userGender: modelGender!),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString())),
        );
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
              CustomTextField(
                controller: _idController,
                hintText: '아이디',
                prefixIcon: const Icon(Icons.person_outline),
              ),
              const SizedBox(height: 16),
              CustomTextField(
                controller: _pwController,
                hintText: '비밀번호',
                obscureText: true,
                prefixIcon: const Icon(Icons.lock_outline),
              ),
              const SizedBox(height: 40),
              CustomButton(text: '로그인', onPressed: _handleLogin),
              const SizedBox(height: 16),
              
            ],
          ),
        ),
      ),
    );
  }
}
