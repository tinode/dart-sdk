import 'package:tinode/src/models/packet-types.dart' as PacketTypes;
import 'package:tinode/src/models/packet.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/models/packet-data.dart';

import 'package:get_it/get_it.dart';
import 'package:tinode/src/services/tools.dart';

class PacketGenerator {
  ConfigService _configService;

  PacketGenerator() {
    _configService = GetIt.I.get<ConfigService>();
  }

  Packet generate(String type, String topicName) {
    PacketData packetData;
    switch (type) {
      case PacketTypes.Hi:
        packetData = HiPacketData(
          ver: _configService.appVersion,
          ua: _configService.userAgent,
          dev: _configService.deviceToken,
          lang: _configService.humanLanguage,
          platf: _configService.platform,
        );
        break;

      case PacketTypes.Acc:
        packetData = AccPacketData(
          user: null,
          scheme: null,
          secret: null,
          login: false,
          tags: null,
          desc: {},
          cred: {},
          token: null,
        );
        break;

      case PacketTypes.Login:
        packetData = LoginPacketData(
          scheme: null,
          secret: null,
          cred: null,
        );
        break;

      case PacketTypes.Sub:
        packetData = SubPacketData(
          topic: topicName,
          set: {},
          get: {},
        );
        break;

      case PacketTypes.Leave:
        packetData = LeavePacketData(
          topic: topicName,
          unsub: false,
        );
        break;

      case PacketTypes.Pub:
        packetData = PubPacketData(
          topic: topicName,
          noecho: false,
          content: {},
          head: null,
          from: null,
          seq: null,
          ts: null,
        );
        break;

      case PacketTypes.Get:
        packetData = GetPacketData(
          topic: topicName,
          what: null,
          desc: {},
          sub: {},
          data: {},
        );
        break;

      case PacketTypes.Set:
        packetData = SetPacketData(
          topic: topicName,
          desc: {},
          sub: {},
          tags: [],
        );
        break;

      case PacketTypes.Del:
        packetData = DelPacketData(
          topic: topicName,
          what: null,
          delseq: null,
          hard: false,
          user: null,
          cred: null,
        );
        break;

      case PacketTypes.Note:
        packetData = NotePacketData(
          topic: topicName,
          seq: null,
          what: null,
        );
        break;
    }

    return Packet(type, packetData, Tools.getNextUniqueId());
  }
}
