import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../splash/splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 사용자 정보 예시 데이터
  final Map<String, dynamic> _userData = {
    'name': '김다온',
    'nickname': '다온',
    'phone': '+82 10-1234-5678',
    'email': 'daon@example.com',
    'address': '서울특별시 강남구',
    'profileImage': 'https://via.placeholder.com/150',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 프로필 정보 섹션
              const Text(
                '내 정보',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 프로필 카드
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                elevation: 3,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: AppColors.lightGrey,
                        backgroundImage: NetworkImage(
                          _userData['profileImage'],
                        ),
                        onBackgroundImageError: (_, __) {},
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: Colors.grey[400],
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _userData['nickname'],
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _userData['email'],
                              style: TextStyle(color: Colors.grey[600]),
                            ),
                            const SizedBox(height: 8),
                            OutlinedButton(
                              onPressed: () {
                                // 프로필 편집 기능
                              },
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: AppColors.primary),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: const Text('프로필 편집'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 계정 설정
              const Text(
                '계정 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SettingsListItem(
                icon: Icons.person_outline,
                title: '개인 정보',
                onTap: () {},
              ),
              SettingsListItem(
                icon: Icons.location_on_outlined,
                title: '주소 수정',
                onTap: () {
                  _showAddressEditDialog(context);
                },
              ),
              SettingsListItem(
                icon: Icons.notifications_outlined,
                title: '알림 설정',
                onTap: () {},
              ),

              const SizedBox(height: 24),

              // 앱 설정
              const Text(
                '앱 설정',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SettingsListItem(
                icon: Icons.language_outlined,
                title: '언어 설정',
                onTap: () {},
              ),
              SettingsListItem(
                icon: Icons.color_lens_outlined,
                title: '테마 설정',
                onTap: () {},
              ),
              SettingsListItem(
                icon: Icons.security_outlined,
                title: '보안 및 개인정보',
                onTap: () {},
              ),

              const SizedBox(height: 24),

              // 로그아웃 및 회원탈퇴
              CustomButton(
                text: '로그아웃',
                onPressed: () {
                  _showLogoutDialog(context);
                },
                backgroundColor: Colors.grey[200],
                textColor: Colors.black87,
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: '회원 탈퇴',
                onPressed: () {
                  _showDeleteAccountDialog(context);
                },
                backgroundColor: Colors.red[50],
                textColor: Colors.red,
              ),

              const SizedBox(height: 40),

              // 앱 정보
              Center(
                child: Column(
                  children: [
                    Text(
                      '버전 1.0.0',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Made by 다온',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showAddressEditDialog(BuildContext context) {
    final TextEditingController addressController = TextEditingController(
      text: _userData['address'],
    );

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('주소 수정'),
            content: TextField(
              controller: addressController,
              decoration: const InputDecoration(hintText: '새 주소를 입력하세요'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _userData['address'] = addressController.text;
                  });
                  Navigator.pop(context);
                },
                child: const Text('저장'),
              ),
            ],
          ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('로그아웃'),
            content: const Text('정말 로그아웃하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SplashScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('로그아웃'),
              ),
            ],
          ),
    );
  }

  void _showDeleteAccountDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('회원 탈퇴'),
            content: const Text(
              '정말 탈퇴하시겠습니까? 계정과 관련된 모든 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('취소'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SplashScreen(),
                    ),
                    (route) => false,
                  );
                },
                child: const Text('탈퇴하기'),
              ),
            ],
          ),
    );
  }
}

class SettingsListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Widget? trailing;

  const SettingsListItem({
    Key? key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.trailing,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.primary),
      title: Text(title),
      trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16),
      onTap: onTap,
    );
  }
}
