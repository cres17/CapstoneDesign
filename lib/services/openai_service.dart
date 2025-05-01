import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String?> analyzeConversation(String conversation) async {
    final prompt = "이 대화를 분석해줘\n$conversation";
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
