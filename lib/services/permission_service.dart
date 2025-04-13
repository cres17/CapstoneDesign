import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  // 화상통화에 필요한 권한 요청
  static Future<bool> requestVideoCallPermissions() async {
    Map<Permission, PermissionStatus> statuses =
        await [Permission.camera, Permission.microphone].request();

    // 모든 권한이 승인되었는지 확인
    return statuses.values.every((status) => status.isGranted);
  }
}
