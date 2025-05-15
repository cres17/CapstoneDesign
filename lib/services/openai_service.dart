import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

class OpenAIService {
  static String get _apiKey => dotenv.env['OPENAI_API_KEY'] ?? '';
  static const String _apiUrl = 'https://api.openai.com/v1/chat/completions';

  Future<Map<String, Map<String, Map<String, String>>>?> analyzeConversation(
    String conversation,
  ) async {
    final prompt = """
너는 대화 분석 전문가이자 화용언어학자야. 아래 대화는 발화자 A와 B가 참여한 실제 대화야.

이 대화를 다음 세 가지 기준에 따라 분석해줘.

1. 적절한 주제 탐색 (협력의 원리, 상호 호혜적 의사소통의 원리)
2. 자아 노출의 적정성 유지 (거리유지의 원칙)
3. 경청과 협력적 반응 (협력의 원리, 공손성의 원리)

각 항목마다 발화자 A와 B의 발화를 평가해줘.
각 항목에서 “잘 드러난 부분”과 “아쉬운 부분”을 **구체적 발화 예시를 포함하여 JSON 형식으로만** 응답해줘.
**설명 없이 아래의 JSON 포맷을 그대로 따라줘.**

{
  "주제탐색": {
    "A": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    },
    "B": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    }
  },
  "자아노출": {
    "A": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    },
    "B": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    }
  },
  "경청협력": {
    "A": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    },
    "B": {
      "잘 드러난 부분": "...",
      "아쉬운 부분": "..."
    }
  }
}

대화:
$conversation
""";
    final body = {
      "model": "o4-mini",
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

    final decodedBody = utf8.decode(response.bodyBytes);

    print('[OpenAIService] 응답 코드: ${response.statusCode}');
    print('[OpenAIService] 응답 바디: $decodedBody');

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
