// existing code...

// 4. 연결 딜레이 줄이기
Future<void> connectToSignalingServer() async {
  try {
    // 연결 시도 전 딜레이 추가
    await Future.delayed(Duration(seconds: 1));
    // 기존 코드 계속...

    // 연결 시도 후 딜레이 추가
    await Future.delayed(Duration(seconds: 1));
  } catch (e) {
    print('시그널링 서버 연결 실패: $e');
  }
}

// 5. 연결 버튼 수정
Future<void> connectToPeer() async {
  try {
    // 연결 시도 전 딜레이 추가
    await Future.delayed(Duration(seconds: 1));
    // 기존 코드 계속...

    // 연결 시도 후 딜레이 추가
    await Future.delayed(Duration(seconds: 1));
  } catch (e) {
    print('피어 연결 실패: $e');
  }
}

// existing code...
