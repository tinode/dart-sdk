import 'package:tinode/src/topic.dart';

class MetaGetBuilder {
  // FIXME: Implement
  String topic;

  MetaGetBuilder(Topic parent) {
    topic = parent.name;
  }

  dynamic withLaterData(dynamic a) {}
  dynamic withEarlierData(dynamic a) {}
  dynamic withOneSub(dynamic a, dynamic b) {}
  dynamic build() {}
}
