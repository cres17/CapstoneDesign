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

// 관심사 리스트
final List<String> interestList = [
  '영화/드라마 감상',
  '음악 감상',
  '독서',
  '운동/스포츠',
  '여행',
  '요리/베이킹',
  '게임',
  '사진/영상 촬영',
  '미술/공예',
  '패션/뷰티',
  'IT/테크',
  '자동차/오토바이',
  '반려동물',
  '자기계발/공부',
  '봉사활동',
  '투자/재테크',
  '건강/피트니스',
  '맛집 탐방',
  '춤/댄스',
  '가드닝/식물 키우기',
];

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

  // 관심사 선택 상태 저장
  List<bool> _selectedInterests = List.generate(20, (index) => false);

  // 회원가입 처리 함수
  Future<void> _handleSignup() async {
    // 관심사 선택값 추출
    List<int> selectedIndexes = [];
    for (int i = 0; i < _selectedInterests.length; i++) {
      if (_selectedInterests[i]) {
        selectedIndexes.add(i + 1);
      }
    }
    String interestsString = selectedIndexes.join(',');

    final error = await AuthService.signup(
      _idController.text.trim(),
      _pwController.text.trim(),
      _nicknameController.text.trim(),
      interestsString,
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

              const SizedBox(height: 24),
              Text('관심사 선택', style: TextStyle(fontWeight: FontWeight.bold)),
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: interestList.length,
                itemBuilder: (context, index) {
                  return CheckboxListTile(
                    title: Text(interestList[index]),
                    value: _selectedInterests[index],
                    onChanged: (bool? value) {
                      setState(() {
                        _selectedInterests[index] = value ?? false;
                      });
                    },
                  );
                },
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
