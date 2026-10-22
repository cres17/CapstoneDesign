import 'package:capstone_porj/services/auth_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('가입 화면의 성별을 예측 서버 형식으로 바꾼다', () {
    expect(AuthService.normalizeGender('남성'), 'male');
    expect(AuthService.normalizeGender('여성'), 'female');
    expect(AuthService.normalizeGender('male'), 'male');
    expect(AuthService.normalizeGender('Female'), 'female');
    expect(AuthService.normalizeGender(null), isNull);
    expect(AuthService.normalizeGender('기타'), isNull);
  });
}
