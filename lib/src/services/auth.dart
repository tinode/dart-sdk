import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/models/auth-token.dart';
import 'package:tinode/src/models/server-messages.dart';

class AuthService {
  String? _userId;
  String? _lastLogin;
  AuthToken? _authToken;
  bool _authenticated = false;

  PublishSubject<OnLoginData> onLogin = PublishSubject<OnLoginData>();

  bool get isAuthenticated {
    return _authenticated;
  }

  AuthToken? get authToken {
    return _authToken;
  }

  String? get userId {
    return _userId;
  }

  String? get lastLogin {
    return _lastLogin;
  }

  void setLastLogin(String lastLogin) {
    _lastLogin = lastLogin;
  }

  void setAuthToken(AuthToken authToken) {
    _authToken = authToken;
  }

  void setUserId(String? userId) {
    _userId = userId;
  }

  void onLoginSuccessful(CtrlMessage? ctrl) {
    if (ctrl == null) {
      return;
    }

    var params = ctrl.params;
    if (params == null || params['user'] == null) {
      return;
    }

    _userId = params['user'];
    _authenticated = (ctrl.code ?? 0) >= 200 && (ctrl.code ?? 0) < 300;

    if (params['token'] != null && params['expires'] != null) {
      _authToken = AuthToken(token: params['token'], expires: DateTime.parse(params['expires']));
    } else {
      _authToken = null;
    }

    onLogin.add(OnLoginData(code: ctrl.code, text: ctrl.text));
  }
}
