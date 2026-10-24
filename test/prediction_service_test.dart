import 'dart:convert';

import 'package:capstone_porj/config/app_config.dart';
import 'package:capstone_porj/services/prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'jwtToken': 'test-token'});
  });

  group('AppConfig', () {
    test('예측은 Node 서버의 /api/predict로만 호출한다', () {
      expect(AppConfig.predictionUrl, '${AppConfig.serverUrl}/api/predict');
      expect(AppConfig.matchingUrl, '${AppConfig.serverUrl}/match');
    });
  });

  group('PredictionService.parseScore', () {
    test('숫자와 한 원소 리스트를 받는다', () {
      expect(PredictionService.parseScore(0.42), 0.42);
      expect(PredictionService.parseScore([0.7]), 0.7);
      expect(PredictionService.parseScore(1), 1.0);
    });

    test('범위 밖이거나 숫자가 아니면 null', () {
      expect(PredictionService.parseScore(1.5), isNull);
      expect(PredictionService.parseScore(-0.1), isNull);
      expect(PredictionService.parseScore('0.5'), isNull);
      expect(PredictionService.parseScore(null), isNull);
      expect(PredictionService.parseScore([]), isNull);
    });
  });

  group('PredictionService.requestScore', () {
    test('대화문과 성별을 토큰과 함께 /api/predict로 보내고 점수를 돌려준다', () async {
      late http.Request sent;
      final client = MockClient((request) async {
        sent = request;
        return http.Response(jsonEncode({'score': 0.83}), 200);
      });

      final score = await PredictionService.requestScore(
        '남: 안녕하세요\n여: 반가워요',
        'female',
        client: client,
      );

      expect(score, 0.83);
      expect(sent.method, 'POST');
      expect(sent.url.toString(), AppConfig.predictionUrl);
      expect(sent.headers['Authorization'], 'Bearer test-token');
      expect(jsonDecode(sent.body), {
        'input_text': '남: 안녕하세요\n여: 반가워요',
        'gender': 'female',
      });
    });

    test('서버 오류나 잘못된 성별·빈 대화면 null', () async {
      final failing = MockClient((_) async => http.Response('error', 500));
      expect(
        await PredictionService.requestScore('대화', 'male', client: failing),
        isNull,
      );

      var called = false;
      final spy = MockClient((_) async {
        called = true;
        return http.Response(jsonEncode({'score': 0.5}), 200);
      });
      expect(
        await PredictionService.requestScore('대화', '남성', client: spy),
        isNull,
      );
      expect(
        await PredictionService.requestScore('  ', 'male', client: spy),
        isNull,
      );
      expect(called, isFalse);
    });
  });
}
