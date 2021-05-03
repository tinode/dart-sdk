import 'package:tinode/src/models/def-acs.dart';

class AccountParams {
  dynamic cred;
  String token;
  DefAcs defacs;
  List<String> tags;
  Map<String, dynamic> public;
  Map<String, dynamic> private;

  AccountParams({
    this.defacs,
    this.public,
    this.private,
    this.tags,
    this.token,
    this.cred,
  });
}
