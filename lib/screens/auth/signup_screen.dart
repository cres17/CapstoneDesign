import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main/main_screen.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _selectedGender = '남성';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('회원가입'),
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // 프로필 사진 업로드
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.lightGrey,
                        border: Border.all(color: AppColors.primary, width: 2),
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: AppColors.darkGrey,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.primary,
                        ),
                        child: IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(
                            Icons.camera_alt,
                            size: 18,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            // 이미지 선택 로직 추가 예정
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

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

              const SizedBox(height: 16),

              // 닉네임 입력 필드
              const CustomTextField(
                hintText: '닉네임',
                prefixIcon: Icon(Icons.face),
              ),

              const SizedBox(height: 16),

              // 성별 선택
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.lightGrey,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.wc, color: AppColors.darkGrey),
                    const SizedBox(width: 16),
                    const Text(
                      '성별',
                      style: TextStyle(color: AppColors.darkGrey),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButton<String>(
                        value: _selectedGender,
                        isExpanded: true,
                        underline: Container(),
                        items:
                            ['남성', '여성'].map((String gender) {
                              return DropdownMenuItem<String>(
                                value: gender,
                                child: Text(gender),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedGender = value!;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // 주소 입력 필드
              const CustomTextField(
                hintText: '주소',
                prefixIcon: Icon(Icons.location_on_outlined),
              ),

              const SizedBox(height: 40),

              // 회원가입 버튼
              CustomButton(
                text: '회원가입',
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const MainScreen()),
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
