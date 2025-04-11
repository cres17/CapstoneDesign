import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
// 웹 환경에서만 dart:html 임포트
import 'dart:ui' as ui;
import 'dart:io';
// ignore: uri_does_not_exist
import 'dart:html' if (dart.library.html) 'dart:html' as html;

class MatchingService {
  // 서버 주소 - 환경에 따라 다르게 설정
  static String get _baseUrl {
    // 웹일 경우 현재 호스트 사용 (CORS 문제 방지)
    if (kIsWeb) {
      try {
        return html.window.location.origin;
      } catch (e) {
        return 'http://172.16.100.225:5000'; // 웹 환경의 기본값
      }
    }

    // 테스트용/개발용 서버 주소 분리
    const bool isProduction = bool.fromEnvironment('dart.vm.product');
    return isProduction
        ? 'http://your-production-server.com:5000' // 프로덕션 서버
        : 'http://172.16.100.225:5000'; // 개발 서버
  }

  // 매칭 요청에 재시도 로직 추가
  static Future<Map<String, dynamic>> requestMatching(
    String userId, {
    int maxRetries = 3,
  }) async {
    int attempts = 0;

    while (attempts < maxRetries) {
      try {
        final response = await http
            .get(Uri.parse('$_baseUrl/match?userId=$userId'))
            .timeout(const Duration(seconds: 10));

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        } else if (response.statusCode == 404) {
          // 매칭 가능한 사용자가 없을 때 잠시 대기 후 재시도
          await Future.delayed(const Duration(seconds: 3));
          attempts++;
          continue;
        } else {
          throw Exception('매칭 요청 실패: ${response.statusCode}');
        }
      } catch (e) {
        print('매칭 오류 (시도 ${attempts + 1}/$maxRetries): $e');

        if (attempts >= maxRetries - 1) {
          rethrow;
        }

        attempts++;
        await Future.delayed(const Duration(seconds: 2));
      }
    }

    throw Exception('최대 재시도 횟수 초과');
  }

  // 연결 테스트
  static Future<bool> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$_baseUrl/test'))
          .timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('서버 연결 테스트 실패: $e');
      return false;
    }
  }
}
