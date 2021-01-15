import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/models/account-params.dart';
import 'package:tinode/src/models/packet-data.dart';
import 'package:tinode/src/models/packet.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/services/packet-generator.dart';
import 'package:tinode/src/models/packet-types.dart' as PacketTypes;

import 'package:get_it/get_it.dart';
import 'package:tinode/src/topic.dart';

/// This class contains basic functionality and logic to
class TinodeService {
  ConnectionService _connectionService;
  PacketGenerator _packetGenerator;
  FutureManager _futureManager;
  LoggerService _loggerService;
  ConfigService _configService;
  CacheManager _cacheManager;

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
}
