import 'package:capstone_porj/services/auth_service.dart';
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../main/main_screen.dart';
import '../../services/auth_service.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  String _selectedGender = '남성';
  File? _profileImage;

  // 추가: 입력값 컨트롤러
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _pwController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();

  // 회원가입 처리 함수
  Future<void> _handleSignup() async {
    final error = await AuthService.signup(
      _idController.text.trim(),
      _pwController.text.trim(),
      _nicknameController.text.trim(),
    );
    if (error == null) {
      // 성공 시 로그인 페이지로 이동
      if (mounted) {
        Navigator.pop(context); // 또는 Navigator.pushReplacement로 LoginScreen 이동
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('회원가입이 완료되었습니다. 로그인 해주세요.')),
        );
      }
      if (_profileImage != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('profile_image_path', _profileImage!.path);
      }
    } else {
      // 에러 메시지 표시
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error)));
      }
    }
  }

  // 이미지 선택 및 로컬 저장 함수
  Future<void> _pickProfileImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.png';
      final savedImage = await File(
        picked.path,
      ).copy('${appDir.path}/$fileName');
      setState(() {
        _profileImage = savedImage;
      });
    }
  }

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
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: AppColors.lightGrey,
                      backgroundImage:
                          _profileImage != null
                              ? FileImage(_profileImage!)
                              : null,
                      child:
                          _profileImage == null
                              ? const Icon(
                                Icons.person,
                                size: 60,
                                color: AppColors.darkGrey,
                              )
                              : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: InkWell(
                        onTap: _pickProfileImage,
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

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

              const SizedBox(height: 16),

              // 닉네임 입력 필드
              CustomTextField(
                controller: _nicknameController,
                hintText: '닉네임',
                prefixIcon: const Icon(Icons.face),
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
              CustomButton(text: '회원가입', onPressed: _handleSignup),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
