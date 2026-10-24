import 'dart:io';
import 'package:flutter/material.dart';
import 'package:capstone_porj/services/api_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../constants/app_colors.dart';
import '../../widgets/custom_button.dart';
import '../splash/splash_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // 로그인 때 기기에 저장한 내 정보
  int? _userId;
  String _nickname = '';
  String _username = '';
  bool _updatingLocation = false;

  File? _profileImageFile;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final path = prefs.getString('profile_image_path');
    final file =
        (path != null && await File(path).exists()) ? File(path) : null;
    if (!mounted) return;
    setState(() {
      _userId = prefs.getInt('user_id');
      _nickname = prefs.getString('nickname') ?? '';
      _username = prefs.getString('username') ?? '';
      _profileImageFile = file;
    });
  }

  ImageProvider? get _profileImage {
    if (_profileImageFile != null) return FileImage(_profileImageFile!);
    if (_userId != null) {
      return NetworkImage('${AppConfig.serverUrl}/user-profile/$_userId', headers: ApiAuth.imageHeaders());
    }
    return null;
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
                        backgroundImage: _profileImage,
                        onBackgroundImageError:
                            _profileImage == null ? null : (_, __) {},
                        child:
                            _profileImage == null
                                ? Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Colors.grey[400],
                                )
                                : null,
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _nickname.isEmpty ? '닉네임 없음' : _nickname,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _username,
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
                title: _updatingLocation ? '주소(위치) 갱신 중…' : '주소 수정',
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

  // 주소 수정: 장소 추천에 쓰는 내 위치를 현재 위치로 갱신한다
  void _showAddressEditDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('주소 수정'),
            content: const Text(
              '현재 위치로 내 주소(위치)를 갱신합니다.\n데이트 장소 추천은 이 위치와 상대방 위치의 중간 지점을 기준으로 합니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _updateLocation();
                },
                child: const Text('현재 위치로 갱신'),
              ),
            ],
          ),
    );
  }

  Future<void> _updateLocation() async {
    if (_updatingLocation) return;
    setState(() => _updatingLocation = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        _showMessage('위치 서비스를 켜 주세요.');
        return;
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showMessage('위치 권한이 필요합니다.');
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      final error = await AuthService.updateLocation(
        position.latitude,
        position.longitude,
      );
      _showMessage(error ?? '주소(위치)를 갱신했습니다.');
    } catch (_) {
      _showMessage('현재 위치를 가져오지 못했습니다.');
    } finally {
      if (mounted) setState(() => _updatingLocation = false);
    }
  }

  void _goToStart() {
    if (!mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (route) => false,
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('로그아웃'),
            content: const Text('정말 로그아웃하시겠습니까?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  await AuthService.logout();
                  _goToStart();
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
          (dialogContext) => AlertDialog(
            title: const Text('회원 탈퇴'),
            content: const Text(
              '정말 탈퇴하시겠습니까? 계정과 관련된 모든 데이터가 삭제됩니다. 이 작업은 되돌릴 수 없습니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('취소'),
              ),
              TextButton(
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  final error = await AuthService.deleteAccount();
                  if (error != null) {
                    _showMessage(error);
                    return;
                  }
                  _goToStart();
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
