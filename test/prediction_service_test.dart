import 'dart:convert';

import 'package:capstone_porj/config/app_config.dart';
import 'package:capstone_porj/services/prediction_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('AppConfig', () {
    test('모델 서버 주소는 serverIp와 5001 포트의 /analyze', () {
      expect(
        AppConfig.modelServerUrl,
        'http://${AppConfig.serverIp}:${AppConfig.modelServerPort}/analyze',
      );
      expect(AppConfig.modelServerPort, 5001);
      expect(AppConfig.serverUrl, 'http://${AppConfig.serverIp}:5000');
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
    test('대화문과 성별을 모델 서버 /analyze로 보내고 점수를 돌려준다', () async {
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
      expect(sent.url.toString(), AppConfig.modelServerUrl);
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
