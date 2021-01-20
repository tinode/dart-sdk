import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/models/del-range.dart';
import 'package:tinode/src/models/get-query.dart';
import 'package:tinode/src/models/message.dart';
import 'package:tinode/src/models/packet.dart';
import 'package:tinode/src/models/set-params.dart';
import 'package:tinode/src/services/auth.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/models/packet-data.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/models/account-params.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/services/packet-generator.dart';
import 'package:tinode/src/models/packet-types.dart' as PacketTypes;
import 'package:tinode/src/models/topic-names.dart' as TopicNames;

import 'package:get_it/get_it.dart';
import 'package:tinode/src/services/tools.dart';
import 'package:tinode/src/topic.dart';

/// This class contains basic functionality and logic to
class TinodeService {
  ConnectionService _connectionService;
  PacketGenerator _packetGenerator;
  FutureManager _futureManager;
  LoggerService _loggerService;
  ConfigService _configService;
  CacheManager _cacheManager;
  AuthService _authService;

  // Events
  PublishSubject<dynamic> onCtrlMessage = PublishSubject<dynamic>();
  PublishSubject<dynamic> onMetaMessage = PublishSubject<dynamic>();
  PublishSubject<dynamic> onDataMessage = PublishSubject<dynamic>();
  PublishSubject<dynamic> onPresMessage = PublishSubject<dynamic>();
  PublishSubject<dynamic> onInfoMessage = PublishSubject<dynamic>();

  TinodeService() {
    _connectionService = GetIt.I.get<ConnectionService>();
    _packetGenerator = GetIt.I.get<PacketGenerator>();
    _futureManager = GetIt.I.get<FutureManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _configService = GetIt.I.get<ConfigService>();
    _cacheManager = GetIt.I.get<CacheManager>();
    _authService = GetIt.I.get<AuthService>();
  }

  void handleCtrlMessage(dynamic packet) {
    var ctrl = packet['ctrl'];
    onCtrlMessage.add(ctrl);

    if (ctrl['id'] != null && ctrl['id'] != 0) {
      _futureManager.execFuture(ctrl['id'], ctrl['code'], ctrl, ctrl['text']);
    }

    if (ctrl['code'] == 205 && ctrl['text'] == 'evicted') {
      Topic topic = _cacheManager.cacheGet('topic', ctrl['topic']);
      if (topic != null) {
        topic.resetSub();
      }
    }

    if (ctrl['params'] != null && ctrl['params']['what'] == 'data') {
      Topic topic = _cacheManager.cacheGet('topic', ctrl['topic']);
      if (topic != null) {
        topic.allMessagesReceived(ctrl['params']['count']);
      }
    }

    if (ctrl['params'] != null && ctrl['params']['what'] == 'sub') {
      Topic topic = _cacheManager.cacheGet('topic', ctrl['topic']);
      if (topic != null) {
        topic.processMetaSub([]);
      }
    }
  }

  void handleMetaMessage(dynamic packet) {
    var meta = packet['meta'];
    onMetaMessage.add(meta);

    Topic topic = _cacheManager.cacheGet('topic', meta['topic']);
    if (topic != null) {
      topic.routeMeta(meta);
    }

    if (meta['id'] != null) {
      _futureManager.execFuture(meta['id'], 200, meta, 'META');
    }
  }

  void handleDataMessage(dynamic packet) {
    var data = packet['data'];
    onDataMessage.add(data);

    Topic topic = _cacheManager.cacheGet('topic', data['topic']);
    if (topic != null) {
      topic.routeMeta(data);
    }
  }

  void handlePresMessage(dynamic packet) {
    var pres = packet['pres'];
    onPresMessage.add(pres);

    Topic topic = _cacheManager.cacheGet('topic', pres['topic']);
    if (topic != null) {
      topic.routePres(pres);
    }
  }

  void handleInfoMessage(dynamic packet) {
    var info = packet['info'];

    Topic topic = _cacheManager.cacheGet('topic', info['topic']);
    if (topic != null) {
      topic.routeInfo(info);
    }
  }

  Future<dynamic> _send(Packet pkt) {
    Future future;

    if (pkt.id != null) {
      future = _futureManager.makeFuture(pkt.id);
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
        print(e);
        _futureManager.execFuture(pkt.id, _configService.appSettings.networkError, null, 'Error');
      } else {
        rethrow;
      }
    }
    return future;
  }

  Future hello() {
    var packet = _packetGenerator.generate(PacketTypes.Hi, null);
    return _send(packet);
  }

  Future account(String userId, String scheme, String secret, bool login, AccountParams params) {
    var packet = _packetGenerator.generate(PacketTypes.Acc, null);
    AccPacketData data = packet.data;
    data.user = userId;
    data.login = login;
    data.scheme = scheme;
    data.secret = secret;

    if (params != null) {
      data.tags = params.tags;
      data.cred = params.cred;
      data.token = params.token;

      data.desc['defacs'] = params.defacs;
      data.desc['public'] = params.public;
      data.desc['private'] = params.private;
    }
    packet.data = data;
    return _send(packet);
  }

  Future login(String scheme, String secret, Map<String, dynamic> cred) async {
    var packet = _packetGenerator.generate(PacketTypes.Login, null);
    LoginPacketData data = packet.data;
    data.scheme = scheme;
    data.secret = secret;
    data.cred = cred;

    packet.data = data;

    var ctrl = await _send(packet);
    _authService.onLoginSuccessful(ctrl);
    return ctrl;
  }

  Future subscribe(String topicName, GetQuery getParams, SetParams setParams) {
    var packet = _packetGenerator.generate(PacketTypes.Sub, topicName);
    SubPacketData data = packet.data;

    if (topicName == '' || topicName == null) {
      topicName = TopicNames.TOPIC_NEW;
    }

    data.get = getParams;

    if (setParams != null) {
      if (setParams.sub != null) {
        data.set.sub = setParams.sub;
      }

      if (setParams.desc != null) {
        if (Tools.isNewGroupTopicName(topicName)) {
          // Full set.desc params are used for new topics only
          data.set.desc = setParams.desc;
        } else if (Tools.topicType(topicName) == 'p2p' && setParams.desc.defacs != null) {
          // Use optional default permissions only.
          data.set.desc = SetDesc(defacs: setParams.desc.defacs);
        }
      }

      if (setParams.tags != null) {
        data.set.tags = setParams.tags;
      }
    }

    packet.data = data;
    return _send(packet);
  }

  Future leave(String topicName, bool unsubscribe) {
    var packet = _packetGenerator.generate(PacketTypes.Leave, topicName);
    LeavePacketData data = packet.data;
    data.unsub = unsubscribe;
    packet.data = data;
    return _send(packet);
  }

  Future publishMessage(Message message) {
    message.resetLocalValues();
    return _send(message.asPubPacket());
  }

  Future getMeta(String topicName, GetQuery params) {
    var packet = _packetGenerator.generate(PacketTypes.Get, topicName);
    GetPacketData data = packet.data;

    data.data = params.data;
    data.desc = params.desc;
    data.what = params.what;
    data.sub = params.sub;

    packet.data = data;
    return _send(packet);
  }

  Future setMeta(String topicName, SetParams params) {
    var packet = _packetGenerator.generate(PacketTypes.Set, topicName);
    SetPacketData data = packet.data;

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

  /// Delete some or all messages in a topic.
  Future deleteMessages(String topicName, List<DelRange> ranges, bool hard) {
    var packet = _packetGenerator.generate(PacketTypes.Del, topicName);
    DelPacketData data = packet.data;
    data.what = 'msg';
    data.delseq = ranges;
    data.hard = hard;
    packet.data = data;
    return _send(packet);
  }

  /// Delete the topic all together. Requires Owner permission.
  Future deleteTopic(String topicName, bool hard) async {
    var packet = _packetGenerator.generate(PacketTypes.Del, topicName);
    DelPacketData data = packet.data;
    data.what = 'topic';
    data.hard = hard;
    packet.data = data;
    var ctrl = await _send(packet);
    _cacheManager.cacheDel('topic', topicName);
    return ctrl;
  }
}
