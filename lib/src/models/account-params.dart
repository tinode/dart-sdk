import 'package:tinode/src/models/credential.dart';
import 'package:tinode/src/models/def-acs.dart';

/// Defined parameters for an account
class AccountParams {
  /// Response to a request for credential verification
  List<Credential>? cred;

  /// Authentication token to use.
  String? token;

  /// Default access parameters for user's `me` topic.
  DefAcs? defacs;

  /// List of string tags for user discovery.
  List<String>? tags;

  /// Public application-defined data exposed on `me` topic.
  Map<String, dynamic>? public;

  /// Private application-defined data accessible on me topic.
  Map<String, dynamic>? private;

  AccountParams({
    this.defacs,
    this.public,
    this.private,
    this.tags,
    this.token,
    this.cred,
  });
}
