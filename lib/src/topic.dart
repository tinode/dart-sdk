import 'dart:async';
import 'dart:math';

import 'package:tinode/src/models/message-status.dart' as message_status;
import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/models/access-mode.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/services/auth.dart';
import 'package:tinode/src/sorted-cache.dart';
import 'package:tinode/src/topic-me.dart';
import 'package:rxdart/rxdart.dart';
import 'package:get_it/get_it.dart';

import 'models/server-messages.dart';
import 'models/set-params.dart';
import 'models/del-range.dart';
import 'models/get-query.dart';
import 'models/message.dart';
import 'models/values.dart';

class Topic {
  bool _new;
  String name;
  AccessMode acs;
  DateTime created;
  DateTime updated;
  bool _subscribed;
  dynamic private;
  int maxDel = 0;
  List<String> tags;

  int seq;
  final int _maxSeq = 0;
  final int _minSeq = 0;
  bool _noEarlierMsgs;

  Map<String, CacheUser> users = {};
  final SortedCache<Message> _messages = SortedCache<Message>((a, b) {
    return a.seq - b.seq;
  }, true);

  AuthService _authService;
  CacheManager _cacheManager;
  TinodeService _tinodeService;
  ConfigService _configService;

  PublishSubject onData = PublishSubject<dynamic>();
  PublishSubject onMetaSub = PublishSubject<CacheUser>();
  PublishSubject onSubsUpdated = PublishSubject<dynamic>();
  PublishSubject onAllMessagesReceived = PublishSubject<int>();

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
    var ctrl = await _tinodeService.subscribe(name != '' ? name : topic_names.TOPIC_NEW, getParams, setParams);

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

      if (name != topic_names.TOPIC_ME && name != topic_names.TOPIC_FND) {
        // Add the new topic to the list of contacts maintained by the 'me' topic.
        TopicMe me = _tinodeService.getTopic(topic_names.TOPIC_ME);
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

    message.setStatus(message_status.SENDING);

    try {
      var ctrl = await _tinodeService.publishMessage(message);
      var seq = ctrl['params']['seq'];
      if (seq != null) {
        message.setStatus(message_status.SENT);
      }
      message.ts = ctrl['ts'];
      swapMessageId(message, seq);

      // TODO: Fix type mismatch
      // routeData(message);
    } catch (e) {
      print('WARNING: Message rejected by the server');
      print(e.toString());
      message.setStatus(message_status.FAILED);
      onData.add(null);
    }
  }

  Future leave(bool unsubscribe) async {
    if (!isSubscribed && !unsubscribe) {
      return Future.error(Exception('Cannot publish on inactive topic'));
    }

    var ctrl = await _tinodeService.leave(name, unsubscribe);
    resetSubscription();
    if (unsubscribe) {
      _cacheManager.delete('topic', name);
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
          _noEarlierMsgs = true;
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

  CacheUser subscriber(String userId) {
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
          toSend.add(DelRange(low: r.low, hi: _maxSeq + 1));
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
    if (_maxSeq == 0 || _maxSeq <= 0) {
      // There are no messages to delete.
      return Future.value();
    }
    return deleteMessages([DelRange(low: 1, hi: _maxSeq + 1, all: true)], hard);
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
    resetSubscription();
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

    TopicMe me = _tinodeService.getTopic(topic_names.TOPIC_ME);
    var user = users[_authService.userId];

    var update = false;
    if (user != null) {
      // if (!user[what] || user[what] < seq) {
      //   user[what] = seq;
      //   update = true;
      // }
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
    seq = seq ?? _maxSeq;
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
    var user = _cacheManager.getUser(uid);
    if (user != null) {
      return user;
    }
  }

  void resetSubscription() {
    _subscribed = false;
  }

  dynamic startMetaQuery() {}
  dynamic gone() {}
  dynamic flushMessage(int a) {}
  dynamic flushMessageRange(int a, int b) {}
  dynamic updateDeletedRanges() {}
  dynamic processMetaCreds(List<dynamic> a, bool b) {}
  dynamic swapMessageId(Message m, int newSeqId) {}
  dynamic processMetaDesc(SetDesc a) {}
  dynamic processMetaTags(List<String> a) {}

  /// This should be called by `Tinode` when all messages are received
  void allMessagesReceived(int count) {
    _updateDeletedRanges();
    onAllMessagesReceived.add(count);
  }

  /// Called by `Tinode` when meta.sub is received or in response to received
  void processMetaSub(List<dynamic> subscriptions) {
    for (var sub in subscriptions) {
      sub['updated'] = DateTime.parse(sub['updated']);
      sub['deleted'] = sub['deleted'] != null ? DateTime.parse(sub['deleted']) : null;

      var user;
      if (sub['deleted'] == null) {
        // If this is a change to user's own permissions, update them in topic too.
        // Desc will update 'me' topic.
        if (_tinodeService.isMe(sub['user']) && sub['acs'] != null) {
          processMetaDesc(SetDesc(
            updated: sub['updated'] ?? DateTime.now(),
            touched: sub['updated'],
            acs: sub['acs'],
          ));
        }
        user = _updateCachedUser(sub['user'], sub);
      } else {
        users.remove(sub['user']);
        user = sub;
      }

      onMetaSub.add(user);
    }
  }

  void routeMeta(MetaMessage meta) {}
  void routeData(DataMessage data) {}
  void routePres(dynamic a) {}
  void routeInfo(dynamic a) {}

  /// Calculate ranges of missing messages
  void _updateDeletedRanges() {
    var ranges = [];
    var prev;

    // Check for gap in the beginning, before the first message.
    var first = _messages.getAt(0);

    if (first != null && _minSeq > 1 && !_noEarlierMsgs) {
      // Some messages are missing in the beginning.
      if (first.hi > 0) {
        // The first message already represents a gap.
        if (first.seq > 1) {
          first.seq = 1;
        }
        if (first.hi < _minSeq - 1) {
          first.hi = _minSeq - 1;
        }
        prev = first;
      } else {
        // Create new gap.
        prev = {'seq': 1, 'hi': _minSeq - 1};
        ranges.add(prev);
      }
    } else {
      // No gap in the beginning.
      prev = {'seq': 0, 'hi': 0};
    }

    // Find gaps in the list of received messages. The list contains messages-proper as well
    // as placeholders for deleted ranges.
    // The messages are iterated by seq ID in ascending order.
    _messages.forEach((data, i) {
      // Do not create a gap between the last sent message and the first unsent.
      if (data.seq >= _configService.appSettings.localSeqId) {
        return;
      }

      // New message is reducing the existing gap
      if (data.seq == (prev['hi'] > 0 ? prev['hi'] : prev.seq) + 1) {
        // No new gap. Replace previous with current.
        prev = data;
        return;
      }

      // Found a new gap.
      if (prev['hi']) {
        // Previous is also a gap, alter it.
        prev['hi'] = data.hi > 0 ? data.hi : data.seq;
        return;
      }

      // Previous is not a gap. Create a new gap.
      prev = {
        'seq': (data.hi > 0 ? data.hi : data.seq) + 1,
        'hi': data.hi > 0 ? data.hi : data.seq,
      };
      ranges.add(prev);
    }, null, null);

    // Check for missing messages at the end.
    // All messages could be missing or it could be a new topic with no messages.
    var last = _messages.getLast();
    var maxSeq = max(seq, _maxSeq) ?? 0;
    if ((maxSeq > 0 && last == null) || (last != null && ((last.hi > 0 ? last.hi : last.seq) < maxSeq))) {
      if (last != null && last.hi > 0) {
        // Extend existing gap
        last.hi = maxSeq;
      } else {
        // Create new gap.
        ranges.add({'seq': last != null ? last.seq + 1 : 1, 'hi': maxSeq});
      }
    }

    // Insert new gaps into cache.
    ranges.map((gap) {
      _messages.put(gap);
    });
  }

  /// Update global user cache and local subscribers cache
  /// Don't call this method for non-subscribers
  CacheUser _updateCachedUser(String userId, Map<String, dynamic> object) {
    var cached = _cacheManager.getUser(userId);
    var merged = {}..addAll(cached.public)..addAll(object);

    // _cacheManager.putUser(userId, CacheUser(merged, userId));
    // users[userId] = CacheUser(merged, userId);
    return users[userId];
  }
}
