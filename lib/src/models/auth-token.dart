class AuthToken {
  /// Authentication token
  final String token;

  /// Expire date of authentication token
  final DateTime expires;

  AuthToken(this.token, this.expires);
}

class OnLoginData {
  /// Response code
  final int code;

  /// Response text
  final String text;

  OnLoginData(
    this.code,
    this.text,
  );
}
