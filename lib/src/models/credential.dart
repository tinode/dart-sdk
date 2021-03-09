/// A data structure representing a credential
class Credential {
  /// Validation method
  final String meth;

  /// Validation value (e.g. email or phone number)
  final String val;

  /// Validation response
  final String resp;

  /// Validation parameters
  final Map<String, dynamic> params;

  // Create a new instance of Credential
  Credential({this.meth, this.val, this.resp, this.params});
}

/// A data structure representing a credential in meta message
class UserCredential {
  /// Validation method
  final String meth;

  /// Validation value (e.g. email or phone number)
  final String val;

  /// Validation status
  final bool done;

  UserCredential({this.meth, this.val, this.done});

  static UserCredential fromMessage(Map<String, dynamic> msg) {
    return UserCredential(
      meth: msg['meth'],
      val: msg['val'],
      done: msg['done'],
    );
  }
}
