class AppConfig {
  // 서버 IP 주소 설정 - 여기만 수정하면 됨
  static const String serverIp = "172.30.37.234";
  static const int serverPort = 5000;

  // 호감도 예측 모델 서버(Flask, server/model_server.py) 포트. 같은 serverIp를 쓴다
  static const int modelServerPort = 5001;

  // 서버 URL 반환 (http)
  static String get serverUrl => "http://$serverIp:$serverPort";

  // 호감도 예측 API URL
  static String get modelServerUrl =>
      "http://$serverIp:$modelServerPort/analyze";

  // WebSocket URL 반환 (ws)
  static String get wsUrl => "ws://$serverIp:$serverPort";

  // API 엔드포인트 생성 헬퍼
  static String getApiUrl(String endpoint) {
    return "$serverUrl/$endpoint";
  }

  // 매칭 API URL 생성 헬퍼
  static String getMatchingUrl(int userId) {
    return "$serverUrl/match?userId=$userId";
  }
}
