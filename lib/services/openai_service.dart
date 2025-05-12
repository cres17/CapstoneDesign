import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String?> analyzeConversation(String conversation) async {
    final prompt = """
아래 대화를 다음 세 가지 기준에 따라 분석해줘.

1. 적절한 주제 탐색 (협력의 원리, 상호 호혜적 의사소통의 원리)
2. 자아 노출의 적정성 유지 (거리유지의 원칙)
3. 경청과 협력적 반응 (협력의 원리, 공손성의 원리)

각 항목별로 대화에서 잘 드러난 부분과 아쉬운 부분을 구체적으로 설명해줘.
$conversation
""";
    final body = {
      "model": "gpt-4.1",
      "messages": [
        {"role": "user", "content": prompt},
      ],
    };

    print('[OpenAIService] 요청 준비: $_apiUrl');
    print('[OpenAIService] 요청 바디: ${jsonEncode(body)}');

    final response = await http.post(
      Uri.parse(_apiUrl),
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer $_apiKey",
      },
      body: jsonEncode(body),
    );

    // 여기서 직접 UTF-8로 디코딩
    final decodedBody = utf8.decode(response.bodyBytes);

    print('[OpenAIService] 응답 코드: ${response.statusCode}');
    print('[OpenAIService] 응답 바디: $decodedBody');

    if (response.statusCode == 200) {
      final data = jsonDecode(decodedBody);
      final content = data['choices']?[0]?['message']?['content'];
      return content?.toString();
    } else {
      print('OpenAI API 오류: $decodedBody');
      return null;
    }
  }
}
