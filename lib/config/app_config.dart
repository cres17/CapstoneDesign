class AppConfig {
  // 서버 IP 주소 설정 - 여기만 수정하면 됨
  static const String serverIp = "192.168.1.50";
  static const int serverPort = 5000;

  // 서버 URL 반환 (http)
  static String get serverUrl => "http://$serverIp:$serverPort";

  // WebSocket URL 반환 (ws)
  static String get wsUrl => "ws://$serverIp:$serverPort";

  // API 엔드포인트 생성 헬퍼
  static String getApiUrl(String endpoint) {
    return "$serverUrl/$endpoint";
  }

  // 매칭 API URL 생성 헬퍼
  static String getMatchingUrl(String userId) {
    return "$serverUrl/match?userId=$userId";
  }
}
