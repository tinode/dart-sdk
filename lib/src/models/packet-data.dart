import 'package:tinode/src/models/get-query.dart';
import 'package:tinode/src/models/set-params.dart';

abstract class PacketData {
  Map<String, dynamic> toMap();
}

class HiPacketData extends PacketData {
  final String ver;
  final String ua;
  final String dev;
  final String lang;
  final String platf;

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
      'ua': ua,
      'ver': ver,
      'dev': dev,
      'lang': lang,
      'platf': platf,
    };
  }
}

class AccPacketData extends PacketData {
  String user;
  String scheme;
  String secret;
  bool login;
  List<String> tags;
  Map<String, dynamic> desc;
  dynamic cred;
  String token;

  AccPacketData({this.user, this.scheme, this.secret, this.login, this.tags, this.desc, this.cred, this.token});

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
  String scheme;
  String secret;
  Map<String, dynamic> cred;

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
  String topic;
  SetParams set;
  GetQuery get;

  SubPacketData({this.topic, this.set, this.get});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'set': set,
      'get': get,
    };
  }
}

class LeavePacketData extends PacketData {
  final String topic;
  final bool unsub;

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
  final String topic;
  final bool noecho;
  final dynamic head;
  final dynamic content;
  final int seq;
  final String from;
  final DateTime ts;

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
  final String topic;
  final String what;
  final dynamic desc;
  final dynamic sub;
  final dynamic data;

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
  final String topic;
  final dynamic desc;
  final dynamic sub;
  final List<String> tags;

  SetPacketData({this.topic, this.desc, this.sub, this.tags});

  @override
  Map<String, dynamic> toMap() {
    return {
      'topic': topic,
      'desc': desc,
      'sub': sub,
      'tags': tags,
    };
  }
}

class DelPacketData extends PacketData {
  final String topic;
  final String what;
  final dynamic delseq;
  final dynamic user;
  final bool hard;
  final dynamic cred;

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
  final String topic;
  final String what;
  final dynamic seq;

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
