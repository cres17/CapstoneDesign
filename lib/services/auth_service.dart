import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:capstone_porj/config/app_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:capstone_porj/services/api_auth.dart';

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
      // 가입 응답의 토큰으로 프로필 사진을 본인 계정에 올린다
      await _saveSession(jsonDecode(utf8.decode(response.bodyBytes)));
      return null; // 성공
    } else {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
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
    // 서버는 토큰의 사용자 계정에만 사진을 저장한다
    request.headers.addAll(await ApiAuth.headers(json: false));
    request.files.add(
      await http.MultipartFile.fromPath(
        'profile_image',
        profileImage.path,
        filename: 'profile.png',
        contentType: _imageContentType(profileImage.path),
      ),
    );
    final streamedResponse = await request.send();
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode == 200) {
      return null; // 성공
    } else {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['error'] ?? '프로필 이미지 업로드 실패';
    }
  }

  static MediaType _imageContentType(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return MediaType('image', 'jpeg');
    }
    if (lower.endsWith('.webp')) return MediaType('image', 'webp');
    return MediaType('image', 'png');
  }

  /// 로그인 · 가입 응답의 사용자 정보와 토큰을 기기에 저장한다.
  static Future<void> _saveSession(dynamic data) async {
    if (data is! Map) return;
    final user = data['user'];
    final prefs = await SharedPreferences.getInstance();
    if (user is Map && user['id'] != null) {
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
    if (data['token'] is String) {
      await ApiAuth.save(data['token']);
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
      await _saveSession(jsonDecode(utf8.decode(response.bodyBytes)));
      return null;
    } else {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['error'] ?? '로그인 실패';
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user_id');
    await ApiAuth.clear();
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
    final token = await ApiAuth.token();
    if (token == null) return null;
    return ApiAuth.headers();
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
