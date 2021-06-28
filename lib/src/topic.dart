import 'package:rxdart/rxdart.dart';
import 'package:get_it/get_it.dart';

import 'dart:async';
import 'dart:math';

import 'package:tinode/src/models/message-status.dart' as message_status;
import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/models/delete-transaction.dart';
import 'package:tinode/src/models/topic-subscription.dart';
import 'package:tinode/src/models/topic-description.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/models/server-messages.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/models/access-mode.dart';
import 'package:tinode/src/models/credential.dart';
import 'package:tinode/src/models/set-params.dart';
import 'package:tinode/src/meta-get-builder.dart';
import 'package:tinode/src/models/del-range.dart';
import 'package:tinode/src/models/get-query.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/models/message.dart';
import 'package:tinode/src/models/def-acs.dart';
import 'package:tinode/src/services/tools.dart';
import 'package:tinode/src/models/values.dart';
import 'package:tinode/src/services/auth.dart';
import 'package:tinode/src/sorted-cache.dart';
import 'package:tinode/src/topic-me.dart';

class Topic {
  /// This topic's name
  String? name;

  /// Timestamp when the topic was created
  DateTime? created;

  /// Timestamp when the topic was last updated
  late DateTime updated;

  /// Timestamp of the last messages
  DateTime? touched;

  /// This topic's access mode
  AccessMode acs = AccessMode(null);

  /// Application-defined data that's available to the current user only
  dynamic private;

  /// Application-defined data that's available to all topic subscribers
  dynamic public;

  /// Locally cached data
  ///
  /// Subscribed users, for tracking read/recv/msg notifications
  final Map<String, TopicSubscription> _users = {};

  /// The maximum known {data.seq} value
  int _maxSeq = 0;

  /// The minimum known {data.seq} value
  int _minSeq = 0;

  /// Indicator that the last request for earlier messages returned 0
  bool _noEarlierMsgs = false;

  /// The maximum known deletion ID
  int _maxDel = 0;

  ///  User discovery tags
  late List<String> tags;

  /// Message cache, sorted by message seq values, from old to new
  final SortedCache<DataMessage> _messages = SortedCache<DataMessage>((a, b) => (a.seq ?? 0) - (b.seq ?? 0), true);

  /// true if the topic is currently live
  bool _subscribed = false;

  /// Timestamp when topic meta-desc update was received
  late DateTime _lastDescUpdate;

  /// Last topic subscribers update timestamp
  DateTime? _lastSubsUpdate;

  /// Topic created but not yet synced with the server. Used only during initialization.
  bool _new = true;

  /// in case some messages were deleted, the greatest ID
  /// of a deleted message, optional
  int? clear;

  /// topic's default access permissions; present only if the current user has 'S' permission
  DefAcs? defacs;

  /// Id of the message user claims through {note} message to have read, optional
  int? read;

  /// Like 'read', but received, optional
  int? recv;

  /// account status; included for `me` topic only, and only if
  /// the request is sent by a root-authenticated session.
  String? status;
  int? seq;

  /// Authentication service, responsible for managing credentials and user id
  late AuthService _authService;

  /// Cache manager service, responsible for read and write operations on cached data
  late CacheManager _cacheManager;

  /// Tinode service, responsible for handling messages, preparing packets and sending them
  late TinodeService _tinodeService;

  /// Configuration service, responsible for storing library config and information
  late ConfigService _configService;

  /// Logger service, responsible for logging content in different levels
  late LoggerService _loggerService;

  /// This event will be triggered when a `data` message is received
  PublishSubject<DataMessage?> onData = PublishSubject<DataMessage?>();

  /// This event will be triggered when a `meta` message is received
  PublishSubject<MetaMessage> onMeta = PublishSubject<MetaMessage>();

  /// This event will be triggered when a `meta.desc` message is received
  PublishSubject<Topic> onMetaDesc = PublishSubject<Topic>();

  /// This event will be triggered when a `meta.sub` message is received
  PublishSubject<TopicSubscription> onMetaSub = PublishSubject<TopicSubscription>();

  /// This event will be triggered when a `pres` message is received
  PublishSubject<PresMessage> onPres = PublishSubject<PresMessage>();

  /// This event will be triggered when a `meta.info` message is received
  PublishSubject<InfoMessage> onInfo = PublishSubject<InfoMessage>();

  /// This event will be triggered when topic subscriptions are updated
  PublishSubject<List<TopicSubscription>> onSubsUpdated = PublishSubject<List<TopicSubscription>>();

  /// This event will be triggered when topic tags are updated
  PublishSubject<List<String>> onTagsUpdated = PublishSubject<List<String>>();

  /// This event will be triggered when all messages are received
  PublishSubject<int> onAllMessagesReceived = PublishSubject<int>();

  Topic(String topicName) {
    _resolveDependencies();
    name = topicName;
  }

  void _resolveDependencies() {
    _authService = GetIt.I.get<AuthService>();
    _cacheManager = GetIt.I.get<CacheManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _tinodeService = GetIt.I.get<TinodeService>();
    _configService = GetIt.I.get<ConfigService>();
  }

  // See if you have subscribed to this topic
  bool get isSubscribed {
    return _subscribed;
  }

  // To set _subscribed manually, Used in unit tests
  set isSubscribed(value) {
    _subscribed = value;
  }

  Future<CtrlMessage> subscribe(GetQuery getParams, SetParams? setParams) async {
    // If the topic is already subscribed, return resolved promise
    if (isSubscribed) {
      return Future.error(Exception('topic is already subscribed'));
    }

    // Send subscribe message, handle async response.
    // If topic name is explicitly provided, use it. If no name, then it's a new group topic, use "new".
    var response = await _tinodeService.subscribe(name ?? topic_names.TOPIC_NEW, getParams, setParams);
    var ctrl = response is CtrlMessage ? response : null;
    var meta = response is MetaMessage ? response : null;

    if (meta != null) {
      return Future.value(CtrlMessage());
    }

    if (ctrl == null) {
      return Future.value(CtrlMessage());
    }

    if (ctrl.code! >= 300) {
      // Do nothing if the topic is already subscribed to.
      return ctrl;
    }

    _subscribed = true;
    acs = (ctrl.params != null && ctrl.params['acs'] != null) ? AccessMode(ctrl.params['acs']) : acs;

    // Set topic name for new topics and add it to cache.
    if (_new) {
      _new = false;

      // Name may change new123456 -> grpAbCdEf
      name = ctrl.topic!;
      created = ctrl.ts!;
      updated = ctrl.ts!;
      // Don't assign touched, otherwise topic will be put on top of the list on subscribe.

      if (name != topic_names.TOPIC_ME && name != topic_names.TOPIC_FND) {
        // Add the new topic to the list of contacts maintained by the 'me' topic.
        var me = _tinodeService.getTopic(topic_names.TOPIC_ME) as TopicMe?;
        if (me != null) {
          me.processMetaSub([
            TopicSubscription(
              noForwarding: true,
              topic: name,
              created: ctrl.ts,
              updated: ctrl.ts,
              acs: acs,
            )
          ]);
        }
      }

      if (setParams != null && setParams.desc != null) {
        setParams.desc!.noForwarding = true;
        processMetaDesc(setParams.desc!);
      }
    }
    return ctrl;
  }

  /// Create a draft of a message without sending it to the server
  Message createMessage(dynamic data, bool echo) {
    return _tinodeService.createMessage(name ?? '', data, echo);
  }

  /// Publish message created by Topic.createMessage.
  Future<CtrlMessage> publishMessage(Message message) async {
    if (!isSubscribed) {
      return Future.error(Exception('Cannot publish on inactive topic'));
    }

    message.setStatus(message_status.SENDING);

    try {
      var response = await _tinodeService.publishMessage(message);
      var ctrl = CtrlMessage.fromMessage(response);

      message.ts = ctrl.ts;
      var seq = ctrl.params['seq'];
      if (seq != null) {
        message.setStatus(message_status.SENT);
      }
      routeData(message.asDataMessage(_authService.userId ?? '', seq));
      return ctrl;
    } catch (e) {
      _loggerService.warn('Message rejected by the server');
      _loggerService.warn(e.toString());
      message.setStatus(message_status.FAILED);
      onData.add(null);
      return Future.value(CtrlMessage());
    }
  }

  /// Leave the topic, optionally unsubscribe. Leaving the topic means the topic will stop
  /// receiving updates from the server. Unsubscribing will terminate user's relationship with the topic.
  ///
  /// Wrapper for Tinode.leave
  Future<CtrlMessage> leave(bool unsubscribe) async {
    if (!isSubscribed && !unsubscribe) {
      return Future.error(Exception('Cannot publish on inactive topic'));
    }

    var ctrl = await _tinodeService.leave(name ?? '', unsubscribe);
    resetSubscription();
    if (unsubscribe) {
      _cacheManager.delete('topic', name ?? '');
      _gone();
    }
    return CtrlMessage.fromMessage(ctrl);
  }

  /// Request topic metadata from the serve
  Future getMeta(GetQuery params) {
    // Send {get} message, return promise.
    return _tinodeService.getMeta(name ?? '', params);
  }

  /// Request more messages from the server
  ///
  /// `limit` - number of messages to get.
  /// `forward` if true, request newer messages.
  Future getMessagesPage(int limit, bool forward) {
    var query = startMetaQuery();
    var future = getMeta(query.build());

    if (forward) {
      query.withLaterData(limit);
    } else {
      query.withEarlierData(limit);
      future = future.then((response) {
        var ctrl = CtrlMessage.fromMessage(response);
        if (ctrl.params != null && (ctrl.params['count'] == null || ctrl.params['count'] == 0)) {
          _noEarlierMsgs = true;
        }
      });
    }

    return future;
  }

  /// Update topic metadata
  Future<CtrlMessage> setMeta(SetParams params) async {
    if (params.tags != null && params.tags!.isNotEmpty) {
      params.tags = Tools.normalizeArray(params.tags!);
    }

    // Send Set message, handle async response.
    var ctrl = await _tinodeService.setMeta(name ?? '', params);

    if (ctrl.code! >= 300) {
      // Not modified
      return ctrl;
    }

    if (params.sub != null) {
      params.sub!.topic = name;

      if (ctrl.params != null && ctrl.params['acs'] != null) {
        params.sub!.acs = AccessMode(ctrl.params['acs']);
        params.sub!.updated = ctrl.ts;
      }

      if (params.sub!.user == null) {
        // This is a subscription update of the current user.
        // Assign user ID otherwise the update will be ignored by _processMetaSub.
        params.sub!.user = _authService.userId;
        params.desc ??= TopicDescription();
      }
      params.sub!.noForwarding = true;

      processMetaSub([params.sub!]);
    }

    if (params.desc != null) {
      if (ctrl.params != null && ctrl.params['acs'] != null) {
        params.desc!.acs = AccessMode(ctrl.params['acs']);
        params.desc!.updated = ctrl.ts;
      }
      processMetaDesc(params.desc!);
    }

    if (params.tags != null) {
      processMetaTags(params.tags!);
    }

    if (params.cred != null) {
      processMetaCreds([params.cred!], true);
    }

    return ctrl;
  }

  /// Update access mode of the current user or of another topic subscriber
  Future<CtrlMessage> updateMode(String? userId, String update) {
    var user = userId != null && userId != '' ? subscriber(userId) : null;
    var am = user != null ? user.acs!.updateGiven(update).getGiven() : getAccessMode().updateWant(update).getWant();
    return setMeta(SetParams(sub: TopicSubscription(user: userId, mode: am)));
  }

  /// Create new topic subscription. Wrapper for Tinode.setMeta
  Future<CtrlMessage> invite(String userId, String mode) {
    return setMeta(SetParams(sub: TopicSubscription(user: userId, mode: mode)));
  }

  /// Archive or un-archive the topic. Wrapper for Tinode.setMeta
  Future archive(bool archive) {
    if (private && private.arch == archive) {
      return Future.error(Exception('Cannot publish on inactive topic'));
    }
    return setMeta(SetParams(desc: TopicDescription(private: {'archive': archive ? true : DEL_CHAR})));
  }

  /// Delete messages. Hard-deleting messages requires Owner permission
  Future<CtrlMessage> deleteMessages(List<DelRange> ranges, bool hard) async {
    if (!isSubscribed) {
      return Future.error(Exception('Cannot delete messages in inactive topic'));
    }

    ranges.sort((r1, r2) {
      if (r1.low! < r2.low!) {
        return 1;
      }
      if (r1.low == r2.low) {
        return r2.hi == 0 || (r1.hi! >= r2.hi!) == true ? 1 : -1;
      }
      return -1;
    });

    // Remove pending messages from ranges possibly clipping some ranges.
    // ignore: omit_local_variable_types
    List<DelRange> toSend = [];
    ranges.forEach((r) {
      if (r.low! < _configService.appSettings.localSeqId) {
        if (r.hi == null || r.hi! < _configService.appSettings.localSeqId) {
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
      result = _tinodeService.deleteMessages(name ?? '', toSend, hard);
    } else {
      result = Future.value({
        'params': {'del': 0}
      });
    }

    var response = await result;
    var ctrl = CtrlMessage.fromMessage(response);

    if (ctrl.params['del'] > _maxDel) {
      _maxDel = ctrl.params['del'];
    }

    ranges.forEach((r) {
      if (r.hi != 0) {
        flushMessageRange(r.low!, r.hi!);
      } else {
        flushMessage(r.low!);
      }
    });

    _updateDeletedRanges();
    // Calling with no parameters to indicate the messages were deleted.
    onData.add(null);
    return ctrl;
  }

  /// Delete all messages. Hard-deleting messages requires Owner permission
  Future<CtrlMessage> deleteMessagesAll(bool hard) {
    if (_maxSeq == 0 || _maxSeq <= 0) {
      // There are no messages to delete.
      return Future.value();
    }
    return deleteMessages([DelRange(low: 1, hi: _maxSeq + 1, all: true)], hard);
  }

  /// Delete multiple messages defined by their IDs. Hard-deleting messages requires Owner permission
  Future<CtrlMessage> deleteMessagesList(List<int> list, bool hard) {
    list.sort((a, b) => a - b);

    // Convert the array of IDs to ranges
    var ranges = <DelRange>[];
    list.map((id) {
      if (ranges.isEmpty) {
        // First element.
        ranges.add(DelRange(low: id));
      } else {
        var prev = ranges[ranges.length - 1];
        if ((prev.hi == null && (id != prev.low! + 1)) || (id > prev.hi!)) {
          // New range.
          ranges.add(DelRange(low: id));
        } else {
          // Expand existing range.
          prev.hi = prev.hi != null ? max(prev.hi!, id + 1) : id + 1;
        }
      }
      return ranges;
    });

    // Send {del} message, return promise
    return deleteMessages(ranges, hard);
  }

  /// Delete topic. Requires Owner permission. Wrapper for Tinode.delTopic
  Future<CtrlMessage> deleteTopic(bool hard) async {
    var ctrl = await _tinodeService.deleteTopic(name ?? '', hard);
    resetSubscription();
    _gone();
    return CtrlMessage.fromMessage(ctrl);
  }

  /// Delete subscription. Requires Share permission. Wrapper for Tinode.deleteSubscription
  Future<CtrlMessage> deleteSubscription(String userId) async {
    if (!isSubscribed) {
      return Future.error(Exception('Cannot delete subscription in inactive topic'));
    }
    // Send {del} message, return promise
    var ctrl = await _tinodeService.deleteSubscription(name ?? '', userId);
    // Remove the object from the subscription cache;
    _users.remove(userId);
    // Notify listeners
    onSubsUpdated.add(_users.values.toList());
    return CtrlMessage.fromMessage((ctrl));
  }

  /// Send a read/recv notification
  void _note(String what, int seq) {
    if (!isSubscribed) {
      // Cannot sending {note} on an inactive topic".
      return;
    }

    var me = _tinodeService.getTopic(topic_names.TOPIC_ME) as TopicMe?;
    var user = _users[_authService.userId];

    var update = false;
    if (user != null) {
      // Known topic subscriber
      if (what == 'read') {
        if (user.read == null || (user.read ?? 0) < seq) {
          user.read = seq;
          update = true;
        }
      } else if (what == 'recv') {
        if (user.recv == null || (user.recv ?? 0) < seq) {
          user.recv = seq;
          update = true;
        }
      }
    } else if (me != null) {
      // Subscriber not found, such as in case of no S permission.
      update = me.getMsgReadRecv(name ?? '', what) < seq;
    }

    if (update) {
      _tinodeService.note(name ?? '', what, seq);
    }

    if (me != null) {
      me.setMsgReadRecv(name ?? '', what, seq, null);
    }
  }

  /// Send a 'recv' receipt. Wrapper for Tinode.noteRecv
  void noteReceive(int seq) {
    _note('recv', seq);
  }

  /// Send a 'read' receipt. Wrapper for Tinode.noteRead
  void noteRead(int? seq) {
    this.seq = seq ?? _maxSeq;
    if (this.seq! > 0) {
      _note('read', this.seq!);
    }
  }

  /// Send a key-press notification. Wrapper for Tinode.noteKeyPress
  void noteKeyPress() {
    if (isSubscribed) {
      _tinodeService.noteKeyPress(name ?? '');
    } else {
      throw Exception('INFO: Cannot send notification in inactive topic');
    }
  }

  /// Get user description from global cache. The user does not need to be a
  /// subscriber of this topic.
  TopicSubscription? userDescription(String userId) {
    var user = _cacheManager.getUser(userId);
    return user;
  }

  /// Get description of the p2p peer from subscription cache
  TopicSubscription? p2pPeerDesc() {
    if (!isP2P()) {
      return null;
    }
    return _users[name];
  }

  /// Get all cached subscriptions for this topic
  Map<String, TopicSubscription> get subscribers {
    return _users;
  }

  /// Get topic's tags
  List<String> getTags() {
    return [...tags];
  }

  /// Get cached subscription for the given user Id
  TopicSubscription? subscriber(String userId) {
    return _users[userId];
  }

  /// Get all cached subscriptions for this topic
  List<DataMessage> get messages {
    return _messages.buffer;
  }

  /// Get the number of topic subscribers who marked this message as either recv or read
  /// Current user is excluded from the count
  int _msgReceiptCount(String what, int seq) {
    var count = 0;
    if (seq > 0) {
      var me = _authService.userId;
      _users.forEach((key, user) {
        if (user.user != me) {
          if (what == 'recv' && (user.recv ?? 0) >= seq) {
            count++;
          }

          if (what == 'read' && (user.read ?? 0) >= seq) {
            count++;
          }
        }
      });
    }
    return count;
  }

  /// Get the number of topic subscribers who marked this message (and all older messages) as read.
  /// The current user is excluded from the count
  ///
  /// seq - Message id to check.
  int msgReadCount(int seq) {
    return _msgReceiptCount('read', seq);
  }

  /// Get the number of topic subscribers who marked this message (and all older messages) as read
  /// The current user is excluded from the count
  ///
  /// seq - Message id to check
  int msgRecvCount(int seq) {
    return _msgReceiptCount('recv', seq);
  }

  /// Check if cached message IDs indicate that the server may have more messages.
  /// newer check for newer messages
  bool msgHasMoreMessages(bool newer) {
    return newer
        ? seq! > _maxSeq
        :
        // _minSeq could be more than 1, but earlier messages could have been deleted.
        (_minSeq > 1 && !_noEarlierMsgs);
  }

  /// Check if the given seq Id is id of the most recent message
  /// seqId id of the message to check
  bool isNewMessage(seqId) {
    return _maxSeq <= seqId;
  }

  DataMessage? flushMessage(int seqId) {
    var idx = _messages.find(DataMessage(seq: seqId), false);
    return idx >= 0 ? _messages.deleteAt(idx) : null;
  }

  void flushMessageRange(int fromId, int untilId) {
    // start, end: find insertion points (nearest == true).
    var since = _messages.find(DataMessage(seq: fromId), true);
    return since >= 0 ? _messages.deleteRange(since, _messages.find(DataMessage(seq: untilId), true)) : [];
  }

  /// Get type of the topic: me, p2p, grp, fnd...
  String? getType() {
    return Tools.topicType(name ?? '');
  }

  /// Get topic's access node
  AccessMode getAccessMode() {
    return acs;
  }

  /// Get topic's default access mode
  DefAcs? getDefaultAccess() {
    return defacs;
  }

  /// Initialize new meta {@link Tinode.GetQuery} builder. The query is attached to the current topic.
  /// It will not work correctly if used with a different topic
  MetaGetBuilder startMetaQuery() {
    return MetaGetBuilder(this);
  }

  /// Check if topic is archived, i.e. private.arch == true.
  bool isArchived() {
    return private != null && private['arch'] ? true : false;
  }

  /// Check if topic is a channel
  bool isChannel() {
    return Tools.isChannelTopicName(name ?? '');
  }

  /// Check if topic is a group topic
  bool isGroup() {
    return Tools.isGroupTopicName(name ?? '');
  }

  /// Check if topic is a p2p topic
  bool isP2P() {
    return Tools.isP2PTopicName(name ?? '');
  }

  /// Process data message
  void routeData(DataMessage data) {
    if (data.content != null) {
      if (touched!.isBefore(data.ts!)) {
        touched = data.ts;
      }
    }

    if (data.seq! > _maxSeq) {
      _maxSeq = data.seq!;
    }

    if (data.seq! < _minSeq || _minSeq == 0) {
      _minSeq = data.seq!;
    }

    if (!data.noForwarding!) {
      _messages.put([data]);
      _updateDeletedRanges();
    }

    onData.add(data);

    // Update locally cached contact with the new message count.
    var me = _tinodeService.getTopic(topic_names.TOPIC_ME) as TopicMe;
    me.setMsgReadRecv(name ?? '', (data.from == null || _tinodeService.isMe(data.from!)) ? 'read' : 'msg', data.seq!, data.ts);
  }

  /// Called by `Tinode`
  ///
  /// Process metadata message
  void routeMeta(MetaMessage meta) {
    if (meta.desc != null) {
      _lastDescUpdate = meta.ts!;
      processMetaDesc(meta.desc!);
    }

    if (meta.sub != null && meta.sub!.isNotEmpty) {
      _lastSubsUpdate = meta.ts!;
      processMetaSub(meta.sub!);
    }

    if (meta.del != null) {
      processDelMessages(meta.del!.clear!, meta.del!.delseq!);
    }

    if (meta.tags != null) {
      processMetaTags(meta.tags!);
    }

    if (meta.cred != null) {
      processMetaCreds(meta.cred!, false);
    }

    onMeta.add(meta);
  }

  /// Process presence change message
  void routePres(PresMessage pres) {
    TopicSubscription? user;
    switch (pres.what) {
      case 'del':
        // Delete cached messages.
        processDelMessages(pres.clear!, pres.delseq!);
        break;

      case 'on':
      case 'off':
        // Update online status of a subscription.
        user = _users[pres.src];
        if (user != null) {
          user.online = pres.what == 'on';
        } else {
          _loggerService.warn('Presence update for an unknown user' + (name ?? '') + ' ' + (pres.src ?? ''));
        }
        break;

      case 'term':
        // Attachment to topic is terminated probably due to cluster rehashing.
        resetSubscription();
        break;

      case 'acs':
        var userId = pres.src ?? _authService.userId;
        user = _users[userId];

        if (user == null) {
          // Update for an unknown user: notification of a new subscription.
          AccessMode? acs = AccessMode(null).updateAll(pres.dacs);
          if (acs.mode != NONE) {
            user = _cacheManager.getUser(userId ?? '');

            // ignore: unnecessary_null_comparison
            if (user == null) {
              user = TopicSubscription(user: userId, acs: acs);
              getMeta(startMetaQuery().withOneSub(null, userId).build());
            } else {
              user.acs = acs;
            }

            user.updated = DateTime.now();
            processMetaSub([user]);
          }
        } else {
          // Known user
          user.acs!.updateAll(pres.dacs);
          // Update user's access mode.
          processMetaSub([TopicSubscription(user: userId, updated: DateTime.now(), acs: user.acs)]);
        }

        break;
      default:
        _loggerService.log('Ignored presence update ' + (pres.what ?? ''));
    }

    onPres.add(pres);
  }

  void routeInfo(InfoMessage info) {
    if (info.what != 'kp') {
      var user = _users[info.from];
      if (user != null) {
        if (info.what == 'recv') {
          user.recv = info.seq;
        }
        if (info.what == 'read') {
          user.read = info.seq;
        }

        if ((user.recv ?? 0) < (user.read ?? 0)) {
          user.recv = user.read;
        }
      }

      // If this is an update from the current user, update the contact with the new count too.
      if (_tinodeService.isMe(info.from ?? '')) {
        var me = _tinodeService.getTopic(topic_names.TOPIC_ME) as TopicMe;
        me.setMsgReadRecv(info.topic!, info.what!, info.seq!, null);
      }
    }
    onInfo.add(info);
  }

  /// Called by Tinode when meta.desc packet is received.
  ///
  /// Called by 'me' topic on contact update (desc._noForwarding is true).
  void processMetaDesc(TopicDescription desc) {
    if (Tools.isP2PTopicName(name!)) {
      desc.defacs = null;
    }

    // Copy parameters from desc object to this topic
    acs = desc.acs ?? acs;
    clear = desc.clear ?? clear;
    created = desc.created ?? created;
    defacs = desc.defacs ?? defacs;
    private = desc.private ?? private;
    public = desc.public ?? public;
    read = desc.read ?? read;
    recv = desc.recv ?? recv;
    seq = desc.seq ?? seq;
    status = desc.status ?? status;
    updated = desc.updated ?? updated;
    touched = desc.touched ?? touched;

    if (name == topic_names.TOPIC_ME && !desc.noForwarding!) {
      var me = _tinodeService.getTopic(topic_names.TOPIC_ME);
      if (me != null) {
        me.processMetaSub([
          TopicSubscription(
            noForwarding: true,
            topic: name,
            updated: updated,
            touched: touched,
            acs: desc.acs,
            seq: desc.seq,
            read: desc.read,
            recv: desc.recv,
            public: desc.public,
            private: desc.private,
          )
        ]);
      }
    }

    onMetaDesc.add(this);
  }

  /// Called by `Tinode` when meta.sub is received or in response to received
  void processMetaSub(List<TopicSubscription> subscriptions) {
    for (var sub in subscriptions) {
      TopicSubscription user;
      if (sub.deleted == null) {
        // If this is a change to user's own permissions, update them in topic too.
        // Desc will update 'me' topic.
        if (_tinodeService.isMe(sub.user!) && sub.acs != null) {
          processMetaDesc(TopicDescription(
            updated: sub.updated ?? DateTime.now(),
            touched: sub.updated,
            acs: sub.acs,
          ));
        }
        user = _updateCachedUser(sub.user!, sub)!;
      } else {
        _users.remove(sub.user);
        user = sub;
      }

      onMetaSub.add(user);
    }
  }

  /// Called by Tinode when meta.tags is received.
  void processMetaTags(List<String> tags) {
    if (tags.isNotEmpty && tags[0] == DEL_CHAR) {
      tags = [];
    }

    this.tags = tags;
    onTagsUpdated.add(tags);
  }

  // Do nothing for topics other than 'me'
  void processMetaCreds(List<Credential> cred, bool a) {}

  /// Delete cached messages and update cached transaction IDs
  void processDelMessages(int clear, List<DeleteTransactionRange> delseq) {
    _maxDel = max(clear, _maxDel);

    if (this.clear != null) {
      this.clear = max(clear, this.clear!);
    }

    var count = 0;
    for (var range in delseq) {
      if (range.hi == null || range.hi == 0) {
        count++;
        flushMessage(range.low!);
      } else {
        for (var i = range.low ?? 0; i < range.hi!; i++) {
          count++;
          flushMessage(i);
        }
      }
    }

    if (count > 0) {
      _updateDeletedRanges();
      onData.add(null);
    }
  }

  /// This should be called by `Tinode` when all messages are received
  void allMessagesReceived(int count) {
    _updateDeletedRanges();
    onAllMessagesReceived.add(count);
  }

  /// Reset subscribed state
  void resetSubscription() {
    _subscribed = false;
  }

  /// This topic is either deleted or unsubscribed from
  void _gone() {
    _messages.reset();
    _users.removeWhere((key, value) => true);
    acs = AccessMode(null);
    private = null;
    public = null;
    _maxSeq = 0;
    _minSeq = 0;
    _subscribed = false;
  }

  /// Update global user cache and local subscribers cache
  /// Don't call this method for non-subscribers
  TopicSubscription? _updateCachedUser(String userId, TopicSubscription object) {
    var cached = _cacheManager.getUser(userId);

    if (cached != null) {
      cached.acs = object.acs ?? cached.acs;
      cached.clear = object.clear ?? cached.clear;
      cached.created = object.created ?? cached.created;
      cached.deleted = cached.deleted ?? cached.deleted;
      cached.mode = object.mode ?? cached.mode;
      cached.noForwarding = object.noForwarding ?? cached.noForwarding;
      cached.online = object.online ?? cached.online;
      cached.private = object.private ?? cached.private;
      cached.public = object.public ?? cached.public;
      cached.read = object.read ?? cached.read;
      cached.recv = object.recv ?? cached.recv;
      cached.seen = object.seen ?? cached.seen;
      cached.seen = object.seen ?? cached.seen;
      cached.topic = object.topic ?? cached.topic;
      cached.touched = object.touched ?? cached.touched;
      cached.updated = object.updated ?? cached.updated;
      cached.user = object.user ?? cached.user;
      _cacheManager.putUser(userId, cached);
    } else {
      _cacheManager.putUser(userId, object);
      cached = object;
    }

    _users[userId] = cached;
    return _users[userId];
  }

  /// Calculate ranges of missing messages
  void _updateDeletedRanges() {
    var ranges = <DataMessage>[];
    DataMessage prev;

    // Check for gap in the beginning, before the first message.
    var first = _messages.length > 0 ? _messages.getAt(0) : null;

    if (first != null && _minSeq > 1 && !_noEarlierMsgs) {
      // Some messages are missing in the beginning.
      if (first.hi != null && (first.hi ?? 0) > 0) {
        // The first message already represents a gap.
        if ((first.seq ?? 0) > 1) {
          first.seq = 1;
        }
        if ((first.hi ?? 0) < _minSeq - 1) {
          first.hi = _minSeq - 1;
        }
        prev = first;
      } else {
        // Create new gap.
        prev = DataMessage(seq: 1, hi: _minSeq - 1);
        ranges.add(prev);
      }
    } else {
      // No gap in the beginning.
      prev = DataMessage(seq: 0, hi: 0);
    }

    // Find gaps in the list of received messages. The list contains messages-proper as well
    // as placeholders for deleted ranges.
    // The messages are iterated by seq ID in ascending order.
    _messages.forEach((data, i) {
      // Do not create a gap between the last sent message and the first unsent.
      if (data.seq! >= _configService.appSettings.localSeqId) {
        return;
      }

      // New message is reducing the existing gap
      if (data.seq == ((prev.hi != null && prev.hi! > 0) ? prev.hi : prev.seq)! + 1) {
        // No new gap. Replace previous with current.
        prev = data;
        return;
      }

      // Found a new gap.
      if (prev.hi != null && prev.hi != 0) {
        // Previous is also a gap, alter it.
        prev.hi = data.hi! > 0 ? data.hi : data.seq;
        return;
      }

      // Previous is not a gap. Create a new gap.
      prev = DataMessage(
        seq: (data.hi! > 0 ? data.hi! : data.seq)! + 1,
        hi: data.hi! > 0 ? data.hi : data.seq,
      );
      ranges.add(prev);
    }, null, null);

    // Check for missing messages at the end.
    // All messages could be missing or it could be a new topic with no messages.
    var last = _messages.length > 0 ? _messages.getLast() : null;
    var maxSeq = max(seq!, _maxSeq);
    if ((maxSeq > 0 && last == null) || (last != null && (((last.hi != null && last.hi! > 0) ? last.hi : last.seq)! < maxSeq))) {
      if (last != null && (last.hi != null && last.hi! > 0)) {
        // Extend existing gap
        last.hi = maxSeq;
      } else {
        // Create new gap.
        ranges.add(DataMessage(seq: last != null ? last.seq! + 1 : 1, hi: maxSeq));
      }
    }

    // Insert new gaps into cache.
    ranges.map((gap) {
      _messages.put([gap]);
    });
  }

  DateTime get lastDescUpdate {
    return _lastDescUpdate;
  }

  DateTime? get lastSubsUpdate {
    return _lastSubsUpdate;
  }

  int get maxSeq {
    return _maxSeq;
  }

  int get minSeq {
    return _minSeq;
  }

  int get maxDel {
    return _maxDel;
  }
}
