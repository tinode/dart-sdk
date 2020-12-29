import 'dart:convert';

import 'package:tinode/src/models/packet.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/services/packet-generator.dart';
import 'package:tinode/src/models/packet-types.dart' as PacketTypes;

import 'package:get_it/get_it.dart';

/// This class contains basic functionality and logic to
class TinodeService {
  ConnectionService _connectionService;
  PacketGenerator _packetGenerator;
  FutureManager _futureManager;
  LoggerService _loggerService;
  ConfigService _configService;

  TinodeService() {
    _connectionService = GetIt.I.get<ConnectionService>();
    _packetGenerator = GetIt.I.get<PacketGenerator>();
    _futureManager = GetIt.I.get<FutureManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _configService = GetIt.I.get<ConfigService>();
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
        _futureManager.execPromise(pkt.id, _configService.appSettings.networkError, null, 'Error');
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
}
