import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:capstone_porj/config/app_config.dart';
import 'package:capstone_porj/services/api_auth.dart';

class OpenAIService {

  Future<Map<String, Map<String, Map<String, String>>>?> analyzeConversation(
    String conversation,
  ) async {
    // OpenAI 키와 프롬프트는 서버(/api/analysis)에 있고, 앱은 대화문만 보낸다.
    // 서버는 OpenAI Chat Completions 응답을 그대로 돌려주므로 아래 파싱은 같다.
    final response = await http.post(
      Uri.parse('${AppConfig.serverUrl}/api/analysis'),
      headers: await ApiAuth.headers(),
      body: jsonEncode({'conversation': conversation}),
    );

    final decodedBody = utf8.decode(response.bodyBytes);

    print('[OpenAIService] 응답 코드: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = jsonDecode(decodedBody);
      final content = data['choices']?[0]?['message']?['content'];
      if (content == null) return null;
      try {
        final Map<String, dynamic> result = jsonDecode(content);
        // Map<String, Map<String, Map<String, String>>> 형태로 변환
        return result.map(
          (k, v) => MapEntry(
            k,
            (v as Map).map(
              (kk, vv) => MapEntry(
                kk.toString(),
                (vv as Map).map(
                  (kkk, vvv) => MapEntry(kkk.toString(), vvv.toString()),
                ),
              ),
            ),
          ),
        );
      } catch (e) {
        print('OpenAI 분석 결과 파싱 오류: $e');
        return null;
      }
    } else {
      print('OpenAI API 오류: $decodedBody');
      return null;
    }
  }
}
