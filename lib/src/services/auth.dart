import 'package:rxdart/rxdart.dart';

import 'package:tinode/src/models/server-messages.dart';
import 'package:tinode/src/models/auth-token.dart';

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
      _authToken =  AuthToken(params['token'],  DateTime.parse(params['expires']), url_encoded_token: Uri.encodeComponent(params['token']));

    } else {
      _authToken = null;
    }

    var code = ctrl.code;
    var text = ctrl.text;
    if (code != null && text != null) {
      onLogin.add(OnLoginData(code, text));
    }
  }
}
