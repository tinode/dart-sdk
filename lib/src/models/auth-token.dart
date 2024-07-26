class AuthToken {
  /// Authentication token
  final String token;
  final String url_encoded_token;

  /// Expire date of authentication token
  final DateTime expires;

  AuthToken(this.token, this.url_encoded_token, this.expires);
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
