import 'package:tinode/src/models/set-params.dart';
import 'package:tinode/src/models/get-query.dart';

abstract class PacketData {
  Map<String, dynamic> toMap();
}

class HiPacketData extends PacketData {
  final String? ver;
  final String? ua;
  final String? dev;
  final String? lang;
  final String? platf;

  HiPacketData({
    this.ua,
    this.ver,
    this.dev,
    this.lang,
    this.platf,
  });

  @override
  Map<String, String> toMap() {
    return {
      'ua': ua ?? '',
      'ver': ver ?? '',
      'dev': dev ?? '',
      'lang': lang ?? '',
      'platf': platf ?? '',
    };
  }
}

class AccPacketData extends PacketData {
  String? user;
  String? scheme;
  String? secret;
  bool? login;
  List<String>? tags;
  Map<String, dynamic>? desc;
  dynamic cred;
  String? token;

  AccPacketData({
    this.user,
    this.scheme,
    this.secret,
    this.login,
    this.tags,
    this.desc,
    this.cred,
    this.token,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'user': user,
      'scheme': scheme,
      'secret': secret,
      'login': login,
      'tags': tags,
      'desc': desc,
      'cred': cred,
      'token': token,
    };
  }
}

class LoginPacketData extends PacketData {
  String? scheme;
  String? secret;
  Map<String, dynamic>? cred;

  LoginPacketData({this.scheme, this.secret, this.cred});

  @override
  Map<String, dynamic> toMap() {
    return {
      'scheme': scheme,
      'secret': secret,
      'cred': cred,
    };
  }
}

class SubPacketData extends PacketData {
  String? topic;
  SetParams? set;
  GetQuery? get;

  SubPacketData({this.topic, this.set, this.get});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'set': set,
      'get': get?.toMap(),
    };
  }
}

class LeavePacketData extends PacketData {
  final String? topic;
  bool? unsub;

  LeavePacketData({this.topic, this.unsub});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'unsub': unsub,
    };
  }
}

class PubPacketData extends PacketData {
  String? topic;
  bool? noecho;
  dynamic head;
  dynamic content;
  int? seq;
  String? from;
  DateTime? ts;

  PubPacketData({this.topic, this.noecho, this.head, this.content, this.seq, this.from, this.ts});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'noecho': noecho,
      'head': head,
      'content': content,
      'seq': seq,
      'from': from,
      'ts': ts,
    };
  }
}

class GetPacketData extends PacketData {
  String? topic;
  String? what;
  dynamic desc;
  dynamic sub;
  dynamic data;

  GetPacketData({this.topic, this.what, this.desc, this.sub, this.data});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'what': what,
      'desc': desc,
      'sub': sub,
      'data': data,
    };
  }
}

class SetPacketData extends PacketData {
  String? topic;
  dynamic desc;
  dynamic sub;
  dynamic cred;
  List<String>? tags;

  SetPacketData({this.topic, this.desc, this.sub, this.tags, this.cred});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'desc': desc,
      'sub': sub,
      'tags': tags,
      'cred': cred,
    };
  }
}

class DelPacketData extends PacketData {
  String? topic;
  String? what;
  dynamic delseq;
  dynamic user;
  bool? hard;
  dynamic cred;

  DelPacketData({this.topic, this.what, this.delseq, this.user, this.hard, this.cred});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'what': what,
      'delseq': delseq,
      'user': user,
      'hard': hard,
      'cred': cred,
    };
  }
}

class NotePacketData extends PacketData {
  String? topic;
  String? what;
  dynamic seq;

  NotePacketData({this.topic, this.what, this.seq});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'what': what,
      'seq': seq,
    };
  }
}
