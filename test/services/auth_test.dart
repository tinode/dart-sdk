import 'package:test/test.dart';

import 'package:tinode/src/models/auth-token.dart';
import 'package:tinode/src/services/auth.dart';

void main() {
  var service = AuthService();

  test('setLastLogin() should set last login', () {
    service.setLastLogin('test');
    expect(service.lastLogin, equals('test'));
  });

  test('setAuthToken() should set auth token', () {
    service.setAuthToken(AuthToken(token: 'token', expires: DateTime.now()));
    expect(service.authToken.token, equals('token'));
  });

  test('setUserId() should set userId', () {
    service.setUserId('test');
    expect(service.userId, equals('test'));
  });
}
