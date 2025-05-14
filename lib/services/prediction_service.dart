import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'clova_speech_service.dart';

class PredictionService {
  final String _modelApiUrl = "http://<서버 IP>:5001/analyze"; // 서버 주소 입력
  final _speechService = ClovaSpeechService();

  /// 점수만 반환하는 간단 예측 함수
  Future<double?> analyzeScoreOnly(String filePath, String userGender) async {
    try {
      final script = await _speechService.requestSpeechToText(filePath);
      if (script == null || script.trim().isEmpty) {
        print('[PredictionService] STT 실패');
        return null;
      }

      final response = await http.post(
        Uri.parse(_modelApiUrl),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "input_text": script,
          "gender": userGender.toLowerCase(),
        }),
      );

      if (response.statusCode != 200) {
        print("[PredictionService] 서버 오류: ${response.body}");
        return null;
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      return _extractScore(decoded['score']);
    } catch (e) {
      print("[PredictionService] 예외 발생: $e");
      return null;
    }
  }

  double _extractScore(dynamic rawScore) {
    if (rawScore is double) return rawScore;
    if (rawScore is List && rawScore.isNotEmpty) {
      return double.tryParse(rawScore.first.toString()) ?? 0.0;
    }
    return double.tryParse(rawScore.toString()) ?? 0.0;
  }
}
