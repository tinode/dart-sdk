import 'package:tinode/tinode.dart';

void main(List<String> args) async {
  var key = 'AQEAAAABAAD_rAp4DJh05a1HAwFT3A6K';
  var host = 'sandbox.tinode.co';

  var tinode = Tinode('Moein', ConnectionOptions(apiKey: key, host: host, secure: true), false);
  await tinode.connect();
  print(tinode.isConnected);
  // await tinode.loginBasic('alice', 'alice123', null);

  // var me = tinode.getMeTopic();
  // me.onSubsUpdated.listen((value) {
  //   for (var item in value) {
  //     print('Subscription: ' + item.public['fn'] + ' - Unread Messages:' + item.unread.toString());
  //   }
  // });
  // await me.subscribe(MetaGetBuilder(me).withLaterSub(null).build(), null);

  // var grp = tinode.getTopic('grpNfK5pjIxPto');
  // grp.onData.listen((value) {
  //   if (value != null) {
  //     print('DataMessage: ' + value.content);
  //   }
  // });
  // await grp.subscribe(MetaGetBuilder(grp).withLaterSub(null).withLaterData(null).build(), null);
  // var msg = grp.createMessage('This is cool', true);
  // await grp.publishMessage(msg);
}
