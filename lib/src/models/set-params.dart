import 'package:tinode/src/models/def-acs.dart';

class SetDesc {
  DefAcs defacs;
  dynamic public;
  dynamic private;
  dynamic acs;
  dynamic updated;
  bool noForwarding;
  int seq;
  dynamic read;
  dynamic recv;
  dynamic touched;

  SetDesc({this.defacs, this.public, this.private, this.acs, this.updated, this.noForwarding, this.seq, this.read, this.recv, this.touched});
}

class SetSub {
  String user;
  String mode;
  dynamic info;
  bool noForwarding;
  String topic;
  dynamic acs;
  dynamic updated;
  dynamic deleted;

  SetSub({this.user, this.mode, this.info, this.noForwarding, this.topic, this.acs, this.updated, this.deleted});
}

class SetParams {
  SetDesc desc;
  SetSub sub;
  List<String> tags;
  dynamic cred;

  SetParams({this.desc, this.sub, this.tags, this.cred});
}
