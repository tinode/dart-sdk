/// A data structure representing a credential
class Credential {
  /// Validation method
  final String? meth;

  /// Validation value (e.g. email or phone number)
  final String? val;

  /// Validation response
  final String? resp;

  /// Check if validation done
  bool? done;

  /// Validation parameters
  final Map<String, dynamic>? params;

  // Create a new instance of Credential
  Credential({this.meth, this.val, this.resp, this.params, this.done});

  static Credential fromMessage(Map<String, dynamic> msg) {
    return Credential(
      meth: msg['meth'],
      val: msg['val'],
      done: msg['done'],
    );
  }
}
