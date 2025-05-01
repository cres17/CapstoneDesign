import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:capstone_porj/config/app_config.dart';

class AuthService {
  static Future<String?> signup(
    String username,
    String password,
    String nickname,
    String interests,
  ) async {
    final url = Uri.parse('${AppConfig.serverUrl}/signup');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username,
        'password': password,
        'nickname': nickname,
        'interests': interests,
      }),
    );
    if (response.statusCode == 201) {
      return null; // 성공
    } else {
      final data = jsonDecode(response.body);
      return data['error'] ?? '회원가입 실패';
    }
  }

  static Future<Map<String, dynamic>?> login(
    String username,
    String password,
  ) async {
    final url = Uri.parse('${AppConfig.serverUrl}/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      final data = jsonDecode(response.body);
      throw data['error'] ?? '로그인 실패';
    }
  }
}
