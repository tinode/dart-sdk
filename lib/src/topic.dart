import 'dart:async';
import 'dart:math';

import 'package:tinode/src/models/message-status.dart' as MessageStatus;
import 'package:tinode/src/models/topic-names.dart' as TopicNames;
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/models/access-mode.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/services/auth.dart';
import 'package:tinode/src/topic-me.dart';
import 'package:rxdart/rxdart.dart';
import 'package:get_it/get_it.dart';

import 'models/set-params.dart';
import 'models/del-range.dart';
import 'models/get-query.dart';
import 'models/message.dart';
import 'models/values.dart';

/// TODO: Implement `attachCacheToTopic` too

class Topic {
  bool _new;
  String name;
  AccessMode acs;
  DateTime created;
  DateTime updated;
  bool _subscribed;
  dynamic private;
  int maxSeq = 0;
  int maxDel = 0;
  List<String> tags;
  bool noEarlierMsgs;
  Map<String, dynamic> users = {};

  AuthService _authService;
  CacheManager _cacheManager;
  TinodeService _tinodeService;
  ConfigService _configService;

  PublishSubject onData = PublishSubject<dynamic>();
  PublishSubject onSubsUpdated = PublishSubject<dynamic>();

  Topic(String topicName) {
    _resolveDependencies();
    name = topicName;
  }

  void _resolveDependencies() {
    _authService = GetIt.I.get<AuthService>();
    _cacheManager = GetIt.I.get<CacheManager>();
    _tinodeService = GetIt.I.get<TinodeService>();
    _configService = GetIt.I.get<ConfigService>();
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

  Future publishMessage(Message message) async {
    if (!isSubscribed) {
      return Future.error(Exception('Cannot publish on inactive topic'));
    }

    message.setStatus(MessageStatus.SENDING);

    try {
      var ctrl = await _tinodeService.publishMessage(message);
      var seq = ctrl['params']['seq'];
      if (seq != null) {
        message.setStatus(MessageStatus.SENT);
      }
      message.ts = ctrl['ts'];
      swapMessageId(message, seq);
      routeData(message);
    } catch (e) {
      print('WARNING: Message rejected by the server');
      print(e.toString());
      message.setStatus(MessageStatus.FAILED);
      onData.add(null);
    }
  }

  Future leave(bool unsubscribe) async {
    if (!isSubscribed && !unsubscribe) {
      return Future.error(Exception('Cannot publish on inactive topic'));
    }

    var ctrl = await _tinodeService.leave(name, unsubscribe);
    resetSub();
    if (unsubscribe) {
      _cacheManager.cacheDel('topic', name);
      gone();
    }
    return ctrl;
  }

  Future getMeta(GetQuery params) {
    return _tinodeService.getMeta(name, params);
  }

  Future getMessagesPage(int limit, bool forward) {
    var query = startMetaQuery();
    var promise = getMeta(query.build());

    if (forward) {
      query.withLaterData(limit);
    } else {
      query.withEarlierData(limit);
      promise = promise.then((ctrl) {
        if (ctrl != null && ctrl['params'] != null && (ctrl['params']['count'] == null || ctrl.params.count == 0)) {
          noEarlierMsgs = true;
        }
      });
    }

    return promise;
  }

  Future setMeta(SetParams params) async {
    // Send Set message, handle async response.
    var ctrl = await _tinodeService.setMeta(name, params);
    if (ctrl && ctrl.code >= 300) {
      // Not modified
      return ctrl;
    }

    if (params.sub != null) {
      params.sub.topic = name;
      if (ctrl['params'] && ctrl['params']['acs']) {
        params.sub.acs = ctrl.params.acs;
        params.sub.updated = ctrl.ts;
      }
      if (params.sub.user == null) {
        // This is a subscription update of the current user.
        // Assign user ID otherwise the update will be ignored by _processMetaSub.
        params.sub.user = _authService.userId;
        params.desc ??= SetDesc();
      }
      params.sub.noForwarding = true;
      processMetaSub([params.sub]);
    }

    if (params.desc != null) {
      if (ctrl.params && ctrl.params.acs) {
        params.desc.acs = ctrl.params.acs;
        params.desc.updated = ctrl.ts;
      }
      processMetaDesc(params.desc);
    }

    if (params.tags != null) {
      processMetaTags(params.tags);
    }

    if (params.cred) {
      processMetaCreds([params.cred], true);
    }

    return ctrl;
  }

  dynamic subscriber(String userId) {
    return users[userId];
  }

  AccessMode getAccessMode() {
    return acs;
  }

  Future updateMode(String userId, String update) {
    var user = userId != null ? subscriber(userId) : null;
    var am = user != null ? user.acs.updateGiven(update).getGiven() : getAccessMode().updateWant(update).getWant();
    return setMeta(SetParams(sub: SetSub(mode: am, user: userId)));
  }

  List<String> getTags() {
    return [...tags];
  }

  Future invite(String userId, String mode) {
    return setMeta(SetParams(sub: SetSub(user: userId, mode: mode)));
  }

  Future archive(bool arch) {
    if (private && private.arch == arch) {
      return Future.error(Exception('Cannot publish on inactive topic'));
    }

    return setMeta(SetParams(desc: SetDesc(private: {'arch': arch ? true : DEL_CHAR})));
  }

  Future deleteMessages(List<DelRange> ranges, bool hard) async {
    if (!isSubscribed) {
      return Future.error(Exception('Cannot delete messages in inactive topic'));
    }

    ranges.sort((r1, r2) {
      if (r1.low < r2.low) {
        return 1;
      }
      if (r1.low == r2.low) {
        return r2.hi == 0 || (r1.hi >= r2.hi) == true ? 1 : -1;
      }
      return -1;
    });

    // Remove pending messages from ranges possibly clipping some ranges.
    // ignore: omit_local_variable_types
    List<DelRange> toSend = [];
    ranges.forEach((r) {
      if (r.low < _configService.appSettings.localSeqId) {
        if (r.hi == 0 || r.hi < _configService.appSettings.localSeqId) {
          toSend.add(r);
        } else {
          // Clip hi to max allowed value.
          toSend.add(DelRange(low: r.low, hi: maxSeq + 1));
        }
      }
    });

    // Send {del} message, return promise
    Future<dynamic> result;
    if (toSend.isNotEmpty) {
      result = _tinodeService.deleteMessages(name, toSend, hard);
    } else {
      result = Future.value({
        'params': {'del': 0}
      });
    }

    var ctrl = await result;

    if (ctrl['params']['del'] > maxDel) {
      maxDel = ctrl.params.del;
    }

    ranges.forEach((r) {
      if (r.hi != 0) {
        flushMessageRange(r.low, r.hi);
      } else {
        flushMessage(r.low);
      }
    });

    updateDeletedRanges();
    // Calling with no parameters to indicate the messages were deleted.
    onData.add(null);
    return ctrl;
  }

  Future deleteMessagesAll(bool hard) {
    if (maxSeq == 0 || maxSeq <= 0) {
      // There are no messages to delete.
      return Future.value();
    }
    return deleteMessages([DelRange(low: 1, hi: maxSeq + 1, all: true)], hard);
  }

  Future deleteMessagesList(List<int> list, bool hard) {
    list.sort((a, b) => a - b);

    var ranges = [];
    // Convert the array of IDs to ranges.
    list.forEach((id) {
      if (ranges.isEmpty) {
        // First element.
        ranges.add({'low': id});
      } else {
        Map<String, int> prev = ranges[ranges.length - 1];
        if ((prev['hi'] == 0 && (id != prev['low'] + 1)) || (id > prev['hi'])) {
          // New range.
          ranges.add({'low': id});
        } else {
          // Expand existing range.
          prev['hi'] = prev['hi'] != null ? max(prev['hi'], id + 1) : id + 1;
        }
      }
      return ranges;
    });

    // Send {del} message, return promise
    return deleteMessages(ranges, hard);
  }

  Future deleteTopic(bool hard) async {
    var ctrl = await _tinodeService.deleteTopic(name, hard);
    resetSub();
    gone();
    return ctrl;
  }

  Future delSubscription(String user) async {
    if (!isSubscribed) {
      return Future.error(Exception('Cannot delete subscription in inactive topic'));
    }
    // Send {del} message, return promise
    var ctrl = await _tinodeService.deleteSubscription(name, user);
    // Remove the object from the subscription cache;
    users.remove(user);
    // Notify listeners
    onSubsUpdated.add(users);
    return ctrl;
  }

  void note(String what, int seq) {
    if (!isSubscribed) {
      // Cannot sending {note} on an inactive topic".
      return;
    }

    TopicMe me = _tinodeService.getTopic(TopicNames.TOPIC_ME);
    var user = users[_authService.userId];

    var update = false;
    if (user) {
      if (!user[what] || user[what] < seq) {
        user[what] = seq;
        update = true;
      }
    } else if (me != null) {
      // Subscriber not found, such as in case of no S permission.
      update = me.getMsgReadRecv(name, what) < seq;
    }

    if (update) {
      _tinodeService.note(name, what, seq);
    }

    if (me != null) {
      me.setMsgReadRecv(name, what, seq);
    }
  }

  void noteRecv(int seq) {
    note('recv', seq);
  }

  void noteRead(int seq) {
    seq = seq ?? maxSeq;
    if (seq > 0) {
      note('read', seq);
    }
  }

  void noteKeyPress() {
    if (isSubscribed) {
      _tinodeService.noteKeyPress(name);
    } else {
      throw Exception('INFO: Cannot send notification in inactive topic');
    }
  }

  dynamic userDesc(String uid) {
    var user = _cacheManager.cacheGetUser(uid);
    if (user) {
      return user; // Promise.resolve(user)
    }
  }

  startMetaQuery() {}
  gone() {}
  flushMessage(int a) {}
  flushMessageRange(int a, int b) {}
  resetSub() {}
  updateDeletedRanges() {}
  processMetaCreds(List<dynamic> a, bool b) {}
  swapMessageId(Message m, int newSeqId) {}
  processMetaDesc(SetDesc a) {}
  processMetaTags(List<String> a) {}
  allMessagesReceived(int count) {}
  processMetaSub(List<dynamic> a) {}
  routeMeta(dynamic a) {}
  routeData(dynamic a) {}
  routePres(dynamic a) {}
  routeInfo(dynamic a) {}
}
