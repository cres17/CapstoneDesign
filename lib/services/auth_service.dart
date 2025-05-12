import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:capstone_porj/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static Future<String?> signup(
    String username,
    String password,
    String nickname,
    String interests,
    String gender, {
    double? latitude,
    double? longitude,
  }) async {
    final url = Uri.parse('${AppConfig.serverUrl}/signup');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'nickname': nickname,
        'interests': interests,
        'gender': gender,
        'latitude': latitude,
        'longitude': longitude,
      }),
    );
    if (response.statusCode == 201) {
      return null; // 성공
    } else {
      final data = jsonDecode(response.body);
      return data['error'] ?? '회원가입 실패';
    }
  }

  // 프로필 이미지 업로드
  static Future<String?> uploadProfileImage(
    String nickname,
    File profileImage,
  ) async {
    final url = Uri.parse('${AppConfig.serverUrl}/upload-profile-image');
    var request = http.MultipartRequest('POST', url);
    request.fields['nickname'] = nickname;
    request.files.add(
      await http.MultipartFile.fromPath(
        'profile_image',
        profileImage.path,
        filename: '$nickname.png',
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return null; // 성공
    } else {
      final data = jsonDecode(response.body);
      return data['error'] ?? '프로필 이미지 업로드 실패';
    }
  }

  static Future<String?> login(String username, String password) async {
    final url = Uri.parse('${AppConfig.serverUrl}/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final user = data['user'];
      if (user != null && user['id'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('user_id', user['id']);
      }
      // 토큰도 필요하면 저장
      if (data['token'] != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('jwtToken', data['token']);
      }
      return null;
    } else {
      final data = jsonDecode(response.body);
      return data['error'] ?? '로그인 실패';
    }
  }
}
