import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/topic-me.dart';
import 'package:tinode/src/topic.dart';
import 'package:get_it/get_it.dart';

class MetaGetBuilder {
  /// Tinode service, responsible for handling messages, preparing packets and sending them
  TinodeService _tinodeService;

  String topic;
  dynamic contact;

  MetaGetBuilder(Topic parent) {
    _tinodeService = GetIt.I.get<TinodeService>();

    topic = parent.name;
    TopicMe me = _tinodeService.getTopic(topic_names.TOPIC_ME);
    contact = me != null ? me.getContact(parent.name) : null;
  }

  dynamic withLaterData(dynamic a) {}
  dynamic withEarlierData(dynamic a) {}
  dynamic withOneSub(dynamic a, dynamic b) {}
  dynamic build() {}
  dynamic withDesc() {}
  dynamic withLaterOneSub(dynamic a) {}
  dynamic withTags() {}
}
