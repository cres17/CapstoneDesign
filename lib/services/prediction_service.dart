import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:capstone_porj/config/app_config.dart';
import 'package:capstone_porj/services/api_auth.dart';

/// 호감도 예측 모델 서버(server/model_server.py) 호출
///
/// Node 서버의 `POST /api/predict {input_text, gender}` → `{score}` (0~1).
/// 모델 서버는 Node 서버 안쪽에만 열려 있고, 앱은 로그인 토큰으로 이 경로만 호출한다.
class PredictionService {
  /// STT로 얻은 대화문과 성별(male/female)로 호감도 점수(0~1)를 요청한다.
  /// 실패하면 null을 돌려준다.
  static Future<double?> requestScore(
    String conversation,
    String gender, {
    http.Client? client,
  }) async {
    if (conversation.trim().isEmpty) return null;
    if (gender != 'male' && gender != 'female') return null;

    final httpClient = client ?? http.Client();
    try {
      final response = await httpClient
          .post(
            Uri.parse(AppConfig.predictionUrl),
            headers: await ApiAuth.headers(),
            body: jsonEncode({'input_text': conversation, 'gender': gender}),
          )
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return null;
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return parseScore(decoded is Map ? decoded['score'] : null);
    } catch (_) {
      return null;
    } finally {
      if (client == null) httpClient.close();
    }
  }

  /// 서버의 score 값(숫자 또는 한 원소 리스트)을 0~1 범위의 double로 바꾼다.
  static double? parseScore(dynamic raw) {
    num? value;
    if (raw is num) {
      value = raw;
    } else if (raw is List && raw.isNotEmpty && raw.first is num) {
      value = raw.first as num;
    }
    if (value == null) return null;
    final score = value.toDouble();
    if (score.isNaN || score < 0 || score > 1) return null;
    return score;
  }
}
