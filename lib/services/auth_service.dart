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
        if (user['nickname'] != null) {
          await prefs.setString('nickname', user['nickname']);
        }
        if (user['username'] != null) {
          await prefs.setString('username', user['username']);
        }
        // 예측 서버는 male/female 모델을 쓰므로 가입 시 저장한 '남성'/'여성'을 변환해 둔다
        final gender = normalizeGender(user['gender']?.toString());
        if (gender != null) {
          await prefs.setString('gender', gender);
        } else {
          await prefs.remove('gender');
        }
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

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await prefs.remove('jwtToken');
    await prefs.remove('nickname');
    await prefs.remove('username');
    await prefs.remove('gender');
    // Provider 등 상태관리도 초기화 필요시 여기에 추가
    // 예: UserProvider.of(context, listen: false).logout();
  }

  /// 가입 화면의 성별('남성'/'여성')을 예측 서버 형식('male'/'female')으로 바꾼다.
  static String? normalizeGender(String? gender) {
    switch (gender?.trim().toLowerCase()) {
      case '남성':
      case '남':
      case 'male':
      case 'm':
        return 'male';
      case '여성':
      case '여':
      case 'female':
      case 'f':
        return 'female';
      default:
        return null;
    }
  }

  static Future<Map<String, String>?> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwtToken');
    if (token == null) return null;
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
    };
  }

  /// 주소(위치) 갱신: 장소 추천에 쓰는 내 좌표를 서버에 저장한다. 성공하면 null.
  static Future<String?> updateLocation(
    double latitude,
    double longitude,
  ) async {
    final userId = await getUserId();
    final headers = await _authHeaders();
    if (userId == null || headers == null) return '로그인이 필요합니다.';
    try {
      final response = await http.put(
        Uri.parse('${AppConfig.serverUrl}/users/$userId/location'),
        headers: headers,
        body: jsonEncode({'latitude': latitude, 'longitude': longitude}),
      );
      if (response.statusCode == 200) return null;
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['error'] ?? '위치를 저장하지 못했습니다.';
    } catch (_) {
      return '서버에 연결할 수 없습니다.';
    }
  }

  /// 회원탈퇴: 서버에서 계정과 관련 기록을 지우고 기기의 로그인 정보도 지운다. 성공하면 null.
  static Future<String?> deleteAccount() async {
    final userId = await getUserId();
    final headers = await _authHeaders();
    if (userId == null || headers == null) return '로그인이 필요합니다.';
    try {
      final response = await http.delete(
        Uri.parse('${AppConfig.serverUrl}/users/$userId'),
        headers: headers,
      );
      if (response.statusCode == 200) {
        await logout();
        return null;
      }
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['error'] ?? '회원탈퇴에 실패했습니다.';
    } catch (_) {
      return '서버에 연결할 수 없습니다.';
    }
  }

  // SharedPreferences에서 user_id를 가져오는 함수
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt('user_id');
    if (userId != null) {
      return userId.toString();
    }
    return null;
  }
}
