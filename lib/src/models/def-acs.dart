/// Topic's default access permissions
class DefAcs {
  /// Default access for authenticated users
  String auth;

  /// Default access for anonymous users
  String anon;

  DefAcs({this.auth, this.anon});

  static DefAcs fromMessage(Map<String, dynamic> msg) {
    return DefAcs(
      anon: msg['anon'],
      auth: msg['auth'],
    );
  }
}
