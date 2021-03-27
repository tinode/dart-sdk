class GetOptsType {
  DateTime ims;
  int limit;
  String topic;
  String user;

  GetOptsType({this.ims, this.limit, this.topic, this.user});

  static GetOptsType fromMessage(Map<String, dynamic> msg) {
    return GetOptsType(
      ims: msg['ims'],
      limit: msg['limit'],
      topic: msg['topic'],
      user: msg['user'],
    );
  }
}

class GetDataType {
  int since;
  int before;
  int limit;

  GetDataType({this.since, this.limit, this.before});

  static GetDataType fromMessage(Map<String, dynamic> msg) {
    return GetDataType(
      since: msg['since'],
      before: msg['before'],
      limit: msg['limit'],
    );
  }
}

class GetQuery {
  bool cred;
  bool tags;
  String what;
  GetOptsType desc;
  GetOptsType sub;
  GetDataType data;
  GetDataType del;

  GetQuery({this.desc, this.sub, this.data, this.what, this.tags, this.cred, this.del});

  static GetQuery fromMessage(Map<String, dynamic> msg) {
    return GetQuery(
      cred: msg['cred'],
      what: msg['what'],
      data: GetDataType.fromMessage(msg['data']),
      del: GetDataType.fromMessage(msg['del']),
      desc: GetOptsType.fromMessage(msg['desc']),
      sub: GetOptsType.fromMessage(msg['sub']),
      tags: msg['tags'],
    );
  }
}
