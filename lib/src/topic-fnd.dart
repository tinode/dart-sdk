import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/models/topic-subscription.dart';
import 'package:tinode/src/models/server-messages.dart';
import 'package:tinode/src/models/set-params.dart';
import 'package:tinode/src/models/message.dart';
import 'package:tinode/src/topic.dart';

/// special case of Topic for searching for contacts and group topics
class TopicFnd extends Topic {
  // List of users and topics uid or topic_name -> Contact object)
  Map<String, TopicSubscription> _contacts = {};

  TopicFnd() : super(topic_names.TOPIC_FND);

  /// Override the original Topic.processMetaSub
  @override
  void processMetaSub(List<TopicSubscription> subscriptions) {
    var updateCount = _contacts.length;
    _contacts = {};

    for (var sub in subscriptions) {
      var indexBy = sub.topic ?? sub.user ?? '';
      _contacts[indexBy] = sub;
      updateCount++;
      onMetaSub.add(sub);
    }

    if (updateCount > 0) {
      onSubsUpdated.add(_contacts.values.toList());
    }
  }

  /// Publishing to TopicFnd is not supported
  @override
  Future<CtrlMessage> publishMessage(Message a) {
    return Future.error(Exception("Publishing to 'fnd' is not supported"));
  }

  /// setMeta to TopicFnd resets contact list in addition to sending the message
  @override
  Future<CtrlMessage> setMeta(SetParams params) async {
    var ctrl = await super.setMeta(params);
    if (_contacts.isNotEmpty) {
      _contacts = {};
      onSubsUpdated.add([]);
    }
    return ctrl;
  }

  List<TopicSubscription> get contacts {
    return _contacts.values.toList();
  }
}
