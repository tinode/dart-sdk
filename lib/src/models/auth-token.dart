class AuthToken {
  final String token;
  final String expires;

  AuthToken({this.token, this.expires});
}

class OnLoginData {
  final int code;
  final String text;

  OnLoginData({this.code, this.text});
}
