import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:get_it/get_it.dart';

import 'package:tinode/src/models/packet-types.dart' as packet_types;
import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/services/packet-generator.dart';
import 'package:tinode/src/models/topic-description.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/models/server-messages.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/models/account-params.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/models/packet-data.dart';
import 'package:tinode/src/models/set-params.dart';
import 'package:tinode/src/models/get-query.dart';
import 'package:tinode/src/models/del-range.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/models/message.dart';
import 'package:tinode/src/services/tools.dart';
import 'package:tinode/src/services/auth.dart';
import 'package:tinode/src/models/packet.dart';
import 'package:tinode/src/topic-fnd.dart';
import 'package:tinode/src/topic-me.dart';
import 'package:tinode/src/topic.dart';

/// This class contains basic functionality and logic to generate and send tinode packages
class TinodeService {
  /// Connection service, responsible for establishing a websocket connection to the server
  late ConnectionService _connectionService;

  /// Packet generator service is responsible for initialize packet objects based on type
  late PacketGenerator _packetGenerator;

  /// Future manager, responsible for making futures and executing them
  late FutureManager _futureManager;

  /// Logger service, responsible for logging content in different levels
  late LoggerService _loggerService;

  /// Configuration service, responsible for storing library config and information
  late ConfigService _configService;

  /// Cache manager service, responsible for read and write operations on cached data
  late CacheManager _cacheManager;

  /// Authentication service, responsible for managing credentials and user id
  late AuthService _authService;

  /// This event will be triggered when a `ctrl` message is received
  PublishSubject<CtrlMessage> onCtrlMessage = PublishSubject<CtrlMessage>();

  /// This event will be triggered when a `meta` message is received
  PublishSubject<MetaMessage> onMetaMessage = PublishSubject<MetaMessage>();

  /// This event will be triggered when a `data` message is received
  PublishSubject<DataMessage> onDataMessage = PublishSubject<DataMessage>();

  /// This event will be triggered when a `pres` message is received
  PublishSubject<PresMessage> onPresMessage = PublishSubject<PresMessage>();

  /// This event will be triggered when a `info` message is received
  PublishSubject<dynamic> onInfoMessage = PublishSubject<dynamic>();

  /// Creates a new instance of TinodeService
  TinodeService() {
    _connectionService = GetIt.I.get<ConnectionService>();
    _packetGenerator = GetIt.I.get<PacketGenerator>();
    _futureManager = GetIt.I.get<FutureManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _configService = GetIt.I.get<ConfigService>();
    _cacheManager = GetIt.I.get<CacheManager>();
    _authService = GetIt.I.get<AuthService>();
  }

  /// Process a packet if the packet type is `ctrl`
  void handleCtrlMessage(CtrlMessage? ctrl) {
    if (ctrl == null) {
      return;
    }

    onCtrlMessage.add(ctrl);

    var code = ctrl.code;
    if (ctrl.id != null && ctrl.id != '' && code != null) {
      _futureManager.execFuture(ctrl.id, code, ctrl, ctrl.text);
    }

    if (ctrl.code == 205 && ctrl.text == 'evicted') {
      Topic? topic = _cacheManager.get('topic', ctrl.topic ?? '');
      if (topic != null) {
        topic.resetSubscription();
      }
    }

    if (ctrl.params != null && ctrl.params['what'] == 'data') {
      Topic? topic = _cacheManager.get('topic', ctrl.topic ?? '');
      if (topic != null) {
        topic.allMessagesReceived(ctrl.params['count']);
      }
    }

    if (ctrl.params != null && ctrl.params['what'] == 'sub') {
      Topic? topic = _cacheManager.get('topic', ctrl.topic ?? '');
      if (topic != null) {
        topic.processMetaSub([]);
      }
    }
  }

  /// Process a packet if the packet type is `meta`
  void handleMetaMessage(MetaMessage? meta) {
    if (meta == null) {
      return;
    }

    onMetaMessage.add(meta);

    Topic? topic = _cacheManager.get('topic', meta.topic ?? '');
    if (topic != null) {
      topic.routeMeta(meta);
    }

    if (meta.id != null) {
      _futureManager.execFuture(meta.id, 200, meta, 'META');
    }
  }

  /// Process a packet if the packet type is `data`
  void handleDataMessage(DataMessage? data) {
    if (data == null) {
      return;
    }

    onDataMessage.add(data);

    Topic? topic = _cacheManager.get('topic', data.topic ?? '');
    if (topic != null) {
      topic.routeData(data);
    }
  }

  /// Process a packet if the packet type is `pres`
  void handlePresMessage(PresMessage? pres) {
    if (pres == null) {
      return;
    }

    onPresMessage.add(pres);

    Topic? topic = pres.topic != null ? _cacheManager.get('topic', pres.topic ?? '') : null;
    if (topic != null) {
      topic.routePres(pres);
    }
  }

  /// Process a packet if the packet type is `info`
  void handleInfoMessage(InfoMessage? info) {
    if (info == null) {
      return;
    }

    Topic? topic = _cacheManager.get('topic', info.topic ?? '');
    if (topic != null) {
      topic.routeInfo(info);
    }
  }

  /// Sends a packet using connection service
  Future<dynamic> _send(Packet pkt) {
    var future = Future<dynamic>.value(null);

    if (pkt.id != null) {
      future = _futureManager.makeFuture(pkt.id ?? '');
    }
    var formattedPkt = pkt.toMap();
    formattedPkt['id'] = pkt.id;
    formattedPkt.keys
        .where((k) => formattedPkt[k] == null || (formattedPkt[k] is Map && formattedPkt[k].isEmpty))
        .toList()
        .forEach(formattedPkt.remove);

    var json = jsonEncode({pkt.name: formattedPkt});
    try {
      _connectionService.sendText(json);
      _loggerService.log('out: ' + json);
    } catch (e) {
      if (pkt.id != null) {
        _loggerService.error(e.toString());
        _futureManager.execFuture(pkt.id, _configService.appSettings.networkError, null, 'Error');
      } else {
        rethrow;
      }
    }

    return future;
  }

  /// Say hello and set some initial configuration
  Future hello({String? deviceToken}) {
    if (deviceToken != null) {
      _configService.deviceToken = deviceToken;
    }
    var packet = _packetGenerator.generate(packet_types.Hi, null);
    return _send(packet);
  }

  /// Create or update an account
  Future account(String userId, String scheme, String secret, bool login, AccountParams? params) {
    Packet? packet = _packetGenerator.generate(packet_types.Acc, null);
    var data = packet.data as AccPacketData;
    data.user = userId;
    data.login = login;
    data.scheme = scheme;
    data.secret = secret;

    if (params != null) {
      data.tags = params.tags;
      data.cred = params.cred;
      data.token = params.token;

      data.desc = {};
      data.desc!['defacs'] = params.defacs;
      data.desc!['public'] = params.public;
      data.desc!['private'] = params.private;
    }
    packet.data = data;
    return _send(packet);
  }

  /// Authenticate current session
  Future<CtrlMessage> login(String scheme, String secret, Map<String, dynamic>? cred) async {
    var packet = _packetGenerator.generate(packet_types.Login, null);
    var data = packet.data as LoginPacketData;
    data.scheme = scheme;
    data.secret = secret;
    data.cred = cred;

    packet.data = data;

    CtrlMessage ctrl = await _send(packet);
    _authService.onLoginSuccessful(ctrl);
    return ctrl;
  }

  /// Send a topic subscription request
  Future subscribe(String? topicName, GetQuery getParams, SetParams? setParams) {
    var packet = _packetGenerator.generate(packet_types.Sub, topicName);
    var data = packet.data as SubPacketData;

    if (topicName == '' || topicName == null) {
      topicName = topic_names.TOPIC_NEW;
    }

    data.get = getParams;

    if (setParams != null) {
      if (setParams.sub != null) {
        data.set?.sub = setParams.sub;
      }

      if (setParams.desc != null) {
        if (Tools.isNewGroupTopicName(topicName)) {
          // Full set.desc params are used for new topics only
          data.set?.desc = setParams.desc;
        } else if (Tools.isP2PTopicName(topicName) && setParams.desc?.defacs != null) {
          // Use optional default permissions only.
          data.set?.desc = TopicDescription(defacs: setParams.desc?.defacs);
        }
      }

      if (setParams.tags != null) {
        data.set?.tags = setParams.tags;
      }
    }

    packet.data = data;
    return _send(packet);
  }

  /// Detach and optionally unsubscribe from the topic
  Future leave(String topicName, bool unsubscribe) {
    var packet = _packetGenerator.generate(packet_types.Leave, topicName);
    var data = packet.data as LeavePacketData;
    data.unsub = unsubscribe;
    packet.data = data;
    return _send(packet);
  }

  Topic? getTopic(String? topicName) {
    Topic? topic = _cacheManager.get('topic', topicName ?? '');
    if (topic == null && topicName != null) {
      if (topicName == topic_names.TOPIC_ME) {
        topic = TopicMe();
      } else if (topicName == topic_names.TOPIC_FND) {
        topic = TopicFnd();
      } else {
        topic = Topic(topicName);
      }
      _cacheManager.put('topic', topicName, topic);
    }
    return topic;
  }

  Topic newTopic() {
    return Topic(topic_names.TOPIC_NEW);
  }

  Topic newChannel() {
    return Topic(topic_names.TOPIC_NEW_CHAN);
  }

  String newGroupTopicName(bool isChan) {
    return (isChan ? topic_names.TOPIC_NEW_CHAN : topic_names.TOPIC_NEW) + Tools.getNextUniqueId();
  }

  Topic newTopicWith(String peerUserId) {
    return Topic(peerUserId);
  }

  /// Create message draft without sending it to the server
  Message createMessage(String topicName, dynamic data, bool? echo) {
    echo ??= true;
    return Message(topicName, data, echo);
  }

  /// Publish message to topic. The message should be created by `createMessage`
  Future publishMessage(Message message) {
    message.resetLocalValues();
    return _send(message.asPubPacket());
  }

  /// Request topic metadata
  Future getMeta(String topicName, GetQuery params) {
    var packet = _packetGenerator.generate(packet_types.Get, topicName);
    var data = packet.data as GetPacketData;

    data.data = params.data?.toMap();
    data.desc = params.desc?.toMap();
    data.what = params.what;
    data.sub = params.sub?.toMap();

    packet.data = data;
    return _send(packet);
  }

  /// Update topic's metadata: description, subscriptions
  Future setMeta(String topicName, SetParams params) {
    var packet = _packetGenerator.generate(packet_types.Set, topicName);
    var data = packet.data as SetPacketData;

    var what = [];
    if (params != null) {
      if (params.desc != null) {
        what.add('desc');
        data.desc = params.desc;
      }
      if (params.sub != null) {
        what.add('sub');
        data.sub = params.sub;
      }
      if (params.tags != null) {
        what.add('tags');
        data.tags = params.tags;
      }
      if (params.cred != null) {
        what.add('cred');
        data.cred = params.cred;
      }

      if (what.isEmpty) {
        throw Exception('Invalid {set} parameters');
      }
    }

    return _send(packet);
  }

  /// Delete some or all messages in a topic
  Future deleteMessages(String topicName, List<DelRange> ranges, bool hard) {
    var packet = _packetGenerator.generate(packet_types.Del, topicName);
    var data = packet.data as DelPacketData;
    data.what = 'msg';
    data.delseq = ranges;
    data.hard = hard;
    packet.data = data;
    return _send(packet);
  }

  /// Delete the topic all together. Requires Owner permission
  Future deleteTopic(String topicName, bool hard) async {
    var packet = _packetGenerator.generate(packet_types.Del, topicName);
    var data = packet.data as DelPacketData;
    data.what = 'topic';
    data.hard = hard;
    packet.data = data;
    var ctrl = await _send(packet);
    _cacheManager.delete('topic', topicName);
    return ctrl;
  }

  /// Delete subscription. Requires Share permission
  Future deleteSubscription(String topicName, String userId) {
    var packet = _packetGenerator.generate(packet_types.Del, topicName);
    var data = packet.data as DelPacketData;
    data.what = 'sub';
    data.user = userId;
    packet.data = data;
    return _send(packet);
  }

  /// Delete credential. Always sent on 'me' topic
  Future deleteCredential(String method, String value) {
    var packet = _packetGenerator.generate(packet_types.Del, topic_names.TOPIC_ME);
    var data = packet.data as DelPacketData;
    data.what = 'cred';
    data.cred = {'meth': method, 'val': value};
    packet.data = data;
    return _send(packet);
  }

  /// Request to delete account of the current user
  Future deleteCurrentUser(bool hard) {
    var packet = _packetGenerator.generate(packet_types.Del, null);
    var data = packet.data as DelPacketData;
    data.hard = hard;
    data.what = 'user';
    packet.data = data;
    return _send(packet);
  }

  /// Notify server that a message or messages were read or received. Does NOT return promise
  Future note(String topicName, String what, int seq) {
    if (seq <= 0 || seq >= _configService.appSettings.localSeqId) {
      throw Exception('Invalid message id ' + seq.toString());
    }

    var packet = _packetGenerator.generate(packet_types.Note, topicName);
    var data = packet.data as NotePacketData;
    data.what = what;
    data.seq = seq;
    packet.data = data;
    return _send(packet);
  }

  /// Broadcast a key-press notification to topic subscribers
  Future noteKeyPress(String topicName) {
    var packet = _packetGenerator.generate(packet_types.Note, topicName);
    var data = packet.data as NotePacketData;
    data.what = 'kp';
    packet.data = data;
    return _send(packet);
  }

  /// Check if the given user ID is equal to the current user's user id
  bool isMe(String userId) {
    return _authService.userId == userId;
  }
}
