import 'dart:async';

import 'package:tinode/src/models/topic-names.dart' as TopicNames;
import 'package:tinode/src/models/access-mode.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/topic-me.dart';
import 'package:get_it/get_it.dart';

import 'models/get-query.dart';
import 'models/message.dart';
import 'models/set-params.dart';

/// TODO: Implement `attachCacheToTopic` too

class Topic {
  bool _new;
  String name;
  AccessMode acs;
  DateTime created;
  DateTime updated;
  bool _subscribed;
  TinodeService _tinodeService;

  Topic(String topicName) {
    _resolveDependencies();
    name = topicName;
  }

  void _resolveDependencies() {
    _tinodeService = GetIt.I.get<TinodeService>();
  }

  // See if you have subscribed to this topic
  bool get isSubscribed {
    return _subscribed;
  }

  Future subscribe(GetQuery getParams, SetParams setParams) async {
    // If the topic is already subscribed, return resolved promise
    if (isSubscribed) {
      return;
    }

    // Send subscribe message, handle async response.
    // If topic name is explicitly provided, use it. If no name, then it's a new group topic, use "new".
    var ctrl = await _tinodeService.subscribe(name != '' ? name : TopicNames.TOPIC_NEW, getParams, setParams);

    if (ctrl['code'] >= 300) {
      // Do nothing if the topic is already subscribed to.
      return ctrl;
    }

    _subscribed = true;
    acs = (ctrl['params'] != null && ctrl['params']['acs'] != null) ? ctrl['params']['acs'] : acs;

    // Set topic name for new topics and add it to cache.
    if (_new) {
      _new = false;

      // Name may change new123456 -> grpAbCdEf
      name = ctrl['topic'];
      created = ctrl['ts'];
      updated = ctrl['ts'];

      if (name != TopicNames.TOPIC_ME && name != TopicNames.TOPIC_FND) {
        // Add the new topic to the list of contacts maintained by the 'me' topic.
        TopicMe me = _tinodeService.getTopic(TopicNames.TOPIC_ME);
        if (me != null) {
          me.processMetaSub([
            {'noForwarding': true, 'topic': name, 'created': ctrl['ts'], 'updated': ctrl['ts'], 'acs': acs}
          ]);
        }
      }

      if (setParams != null && setParams.desc != null) {
        setParams.desc.noForwarding = true;
        processMetaDesc(setParams.desc);
      }
    }
    return ctrl;
  }

  Message createMessage(dynamic data, bool echo) {
    return _tinodeService.createMessage(name, data, echo);
  }

  resetSub() {}
  processMetaDesc(SetDesc a) {}
  allMessagesReceived(int count) {}
  processMetaSub(List<dynamic> a) {}
  routeMeta(dynamic a) {}
  routeData(dynamic a) {}
  routePres(dynamic a) {}
  routeInfo(dynamic a) {}
}
