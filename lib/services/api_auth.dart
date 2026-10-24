import 'package:shared_preferences/shared_preferences.dart';

/// 서버 요청에 붙일 로그인 토큰(JWT) 헤더.
///
/// 서버는 요청 본문이나 경로의 사용자 id 대신 이 토큰의 사용자만 신뢰한다.
class ApiAuth {
  static const tokenKey = 'jwtToken';
  static String? _cached;

  /// 앱 시작 시 저장된 토큰을 읽어 둔다. 이미지 위젯처럼 동기 헤더가 필요한 곳에서 쓴다.
  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _cached = prefs.getString(tokenKey);
  }

  static Future<void> save(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(tokenKey, token);
    _cached = token;
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(tokenKey);
    _cached = null;
  }

  static Future<String?> token() async {
    if (_cached != null) return _cached;
    await load();
    return _cached;
  }

  /// `Authorization: Bearer <token>` 헤더. [json]이면 Content-Type도 함께 넣는다.
  static Future<Map<String, String>> headers({bool json = true}) async {
    final t = await token();
    return {
      if (json) 'Content-Type': 'application/json',
      if (t != null) 'Authorization': 'Bearer $t',
    };
  }

  /// 프로필 사진처럼 위젯에서 바로 불러오는 이미지 요청용 헤더
  static Map<String, String> imageHeaders() => {
        if (_cached != null) 'Authorization': 'Bearer $_cached',
      };
}
