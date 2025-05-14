final prefs = await SharedPreferences.getInstance();
final userId = prefs.getInt('userId'); // ❌ 잘못된 키
if (userId != null) {
  print('[SignalingService] 사용자 등록 시도: $userId');
  socket?.emit('register', userId.toString());
} 