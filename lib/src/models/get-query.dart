class GetOptsType {
  DateTime ims;
  int limit;

  GetOptsType({this.ims, this.limit});
}

class GetDataType {
  int since;
  int before;
  int limit;

  GetDataType({this.since, this.limit, this.before});
}

class GetQuery {
  GetOptsType desc;
  GetOptsType sub;
  GetDataType data;
  String what;

  GetQuery({this.desc, this.sub, this.data, this.what});
}
