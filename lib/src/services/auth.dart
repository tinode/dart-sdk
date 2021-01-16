import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/models/auth-token.dart';

class AuthService {
  String _userId;
  String _lastLogin;
  AuthToken _authToken;
  bool _authenticated = false;

  PublishSubject<OnLoginData> onLogin = PublishSubject<OnLoginData>();

  bool get isAuthenticated {
    return _authenticated;
  }

  AuthToken get authToken {
    return _authToken;
  }

  String get userId {
    return _userId;
  }

  String get lastLogin {
    return _lastLogin;
  }

  void setLastLogin(String lastLogin) {
    _lastLogin = lastLogin;
  }

  void onLoginSuccessful(Map<String, dynamic> ctrl) {
    var params = ctrl['params'];
    if (params == null || params['user'] == null) {
      return;
    }

    _userId = params['user'];
    _authenticated = ctrl['code'] >= 200 && ctrl['code'] < 300;

    if (params['token'] != null && params['expires'] != null) {
      _authToken = AuthToken(token: params['token'], expires: DateTime.parse(params['expires']));
    } else {
      _authToken = null;
    }

    onLogin.add(OnLoginData(code: ctrl['code'], text: ctrl['text']));
  }
}
