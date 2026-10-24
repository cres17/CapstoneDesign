class AppConfig {
  // 서버 주소. 빌드할 때 --dart-define=SERVER_URL=https://api.example.com 으로 바꿀 수 있다.
  // 실제 배포에서는 비밀번호와 토큰이 평문으로 오가지 않도록 HTTPS 주소를 지정한다.
  static const String serverUrl = String.fromEnvironment(
    'SERVER_URL',
    defaultValue: 'http://172.30.37.234:5000',
  );

  // 호감도 예측 API. 모델 서버(model_server.py)는 Node 서버 안쪽에 두고 이 경로로만 호출한다
  static String get predictionUrl => '$serverUrl/api/predict';

  // API 엔드포인트 생성 헬퍼
  static String getApiUrl(String endpoint) {
    return "$serverUrl/$endpoint";
  }

  // 매칭 API URL (사용자는 서버가 토큰으로 판별한다)
  static String get matchingUrl => "$serverUrl/match";
}
