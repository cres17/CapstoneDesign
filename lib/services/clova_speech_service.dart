import 'dart:convert';
import 'dart:io';
import 'package:capstone_porj/config/app_config.dart';
import 'package:capstone_porj/services/api_auth.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class ClovaSpeechService {
  Future<String?> requestSpeechToText(String filePath) async {
    // CLOVA Speech 키는 서버에만 있고, 앱은 녹음 파일을 서버의 /api/stt로 보낸다.
    // 서버는 CLOVA 응답을 그대로 돌려주므로 아래 파싱은 같다.
    final url = '${AppConfig.serverUrl}/api/stt';

    final file = File(filePath);
    if (!await file.exists()) {
      print('[ClovaSpeechService] 녹음 파일이 존재하지 않습니다: $filePath');
      return null;
    }
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      print('[ClovaSpeechService] 녹음 파일이 비어 있습니다: $filePath');
      return null;
    }

    // 요청 전 상세 로그 출력
    print('--- [ClovaSpeechService] API 요청 준비 ---');
    print('파일 경로: $filePath');
    print('파일 크기: ${bytes.length} bytes');
    print('fields: diarization=true, language=ko-KR');
    print('----------------------------------------');

    final request = http.MultipartRequest('POST', Uri.parse(url));
    request.headers.addAll(await ApiAuth.headers(json: false));
    request.headers['Accept'] = 'application/json';
    request.files.add(
      http.MultipartFile.fromBytes(
        'media',
        bytes,
        filename: 'call_record.aac',
        contentType: MediaType('audio', 'aac'),
      ),
    );

    try {
      final streamedResponse = await request.send();
      final responseBody = await streamedResponse.stream.bytesToString();
      print('--- [ClovaSpeechService] API 응답 ---');
      print(responseBody);

      if (responseBody.contains('"text":') ||
          responseBody.contains('"segments":')) {
        final data = jsonDecode(responseBody);

        // segments가 있으면 화자별로 텍스트를 합쳐서 반환
        if (data['segments'] != null && data['segments'] is List) {
          final segments = data['segments'] as List;
          final buffer = StringBuffer();
          for (final seg in segments) {
            final speaker =
                seg['speaker']?['name'] ?? seg['diarization']?['label'] ?? '';
            final text = seg['text'] ?? '';
            buffer.writeln('${speaker.isNotEmpty ? speaker : "화자"}: $text');
          }
          return buffer.toString().trim();
        }

        // segments가 없으면 기존 방식대로
        return data['text'] ??
            data['segments']?.map((seg) => seg['text']).join('\n');
      } else {
        print('Clova Speech API 오류: $responseBody');
        return null;
      }
    } catch (e, st) {
      print('Clova Speech API 요청 중 예외 발생: $e');
      print(st);
      return null;
    }
  }
}
