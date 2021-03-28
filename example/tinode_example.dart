import 'package:tinode/tinode.dart';

void main(List<String> args) async {
  var key = 'AQEAAAABAAD_rAp4DJh05a1HAwFT3A6K';
  var host = 'sandbox.tinode.co';

  var tinode = Tinode('Moein', ConnectionOptions(apiKey: key, host: host, secure: true), false);
  await tinode.connect();
  await tinode.loginBasic('alice', 'alice123', null);

  var me = tinode.getMeTopic();
  me.onSubsUpdated.listen((value) {
    for (var v in value) {
      print(v.topic);
    }
  });

  await me.subscribe(MetaGetBuilder(me).withLaterSub(null).build(), null);
}
