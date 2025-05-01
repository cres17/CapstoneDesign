import 'dart:math' as math;

class CallResultData {
  static String? transcriptText;
  static DateTime? callEndTime;

  // 통화 결과 저장 메서드
  static void saveCallResult(String? text) {
    print(
      '[CallResultData] 통화 결과 저장: ${text?.substring(0, math.min(30, text?.length ?? 0))}...',
    );
    transcriptText = text;
    callEndTime = DateTime.now();
    print(
      '[CallResultData] 저장 완료 - 시간: $callEndTime, 텍스트 길이: ${text?.length ?? 0}',
    );
  }

  // 통화 결과 확인 메서드
  static bool hasResult() {
    final hasData = transcriptText != null && transcriptText!.isNotEmpty;
    print('[CallResultData] 통화 결과 확인: $hasData');
    return hasData;
  }

  // 통화 결과 초기화 메서드
  static void clear() {
    print('[CallResultData] 통화 결과 초기화');
    transcriptText = null;
    callEndTime = null;
  }
}
