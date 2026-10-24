import 'package:capstone_porj/services/api_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('저장된 토큰을 Authorization 헤더로 붙이고, 로그아웃하면 지운다', () async {
    SharedPreferences.setMockInitialValues({});
    await ApiAuth.clear();
    expect(await ApiAuth.headers(), {'Content-Type': 'application/json'});
    expect(ApiAuth.imageHeaders(), isEmpty);

    await ApiAuth.save('abc');
    expect(await ApiAuth.headers(json: false), {'Authorization': 'Bearer abc'});
    expect(ApiAuth.imageHeaders(), {'Authorization': 'Bearer abc'});

    await ApiAuth.clear();
    expect(await ApiAuth.token(), isNull);
  });
}
