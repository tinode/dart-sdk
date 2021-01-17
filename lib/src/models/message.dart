import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/models/packet.dart';
import 'package:tinode/src/models/drafty.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/models/packet-data.dart';
import 'package:tinode/src/services/packet-generator.dart';
import 'package:tinode/src/models/packet-types.dart' as PacketTypes;
import 'package:tinode/src/models/message-status.dart' as MessageStatus;

class Message {
  int seq;
  bool echo;
  int _status;
  DateTime ts;
  String from;
  bool cancelled;
  dynamic content;
  String topicName;
  bool noForwarding;

  PacketGenerator _packetGenerator;

  PublishSubject<int> onStatusChange = PublishSubject<int>();

  Message(this.topicName, this.content, this.echo) {
    _status = MessageStatus.NONE;
    _packetGenerator = GetIt.I.get<PacketGenerator>();
  }

  Packet asPubPacket() {
    var packet = _packetGenerator.generate(PacketTypes.Pub, topicName);
    PubPacketData data = packet.data;
    var dft;
    if (content is String) {
      dft = Drafty.parse(content);
    } else {
      dft = content;
    }

    data.content = content;
    data.noecho = !echo;

    if (dft != null && !Drafty.isPlainText(dft)) {
      data.head = {'mime': Drafty.getContentType()};
      data.content = dft;

      if (Drafty.hasAttachments(data.content) && data.head.attachments == null) {
        var attachments = [];
        Drafty.attachments(data.content, (dynamic data) {
          attachments.add(data.ref);
        });
        data.head.attachments = attachments;
      }
    }

    packet.data = data;
    return packet;
  }

  void setStatus(int status) {
    _status = status;
    onStatusChange.add(status);
  }

  int getStatus() {
    return _status;
  }

  void resetLocalValues() {
    seq = null;
    from = null;
    ts = null;
  }
}
