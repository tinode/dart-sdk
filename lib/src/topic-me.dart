import 'package:tinode/src/topic.dart';

class TopicMe extends Topic {
  TopicMe() : super('me');

  dynamic getContact(dynamic a) {}
  getMsgReadRecv(String name, String what) {}
  setMsgReadRecv(String name, String what, int seq, DateTime ts) {}
}
