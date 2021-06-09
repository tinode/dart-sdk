import 'package:tinode/tinode.dart';

void main(List<String> args) async {
  var key = 'AQEAAAABAAD_rAp4DJh05a1HAwFT3A6K';
  var host = 'sandbox.tinode.co';

  var loggerEnabled = true;
  var tinode = Tinode('Moein', ConnectionOptions(host, key, secure: true), loggerEnabled);
  await tinode.connect();
  print('Is Connected:' + tinode.isConnected.toString());
  var result = await tinode.loginBasic('alice', 'alice123', null);
  print('User Id: ' + result.params['user'].toString());

  var me = tinode.getMeTopic();
  me.onSubsUpdated.listen((value) {
    for (var item in value) {
      print('Subscription[' + item.topic.toString() + ']: ' + item.public['fn'] + ' - Unread Messages:' + item.unread.toString());
    }
  });
  await me.subscribe(MetaGetBuilder(me).withLaterSub(null).build(), null);

  var grp = tinode.getTopic('grpWAFkncfrJtc');
  grp.onData.listen((value) {
    if (value != null) {
      print('DataMessage: ' + value.content);
    }
  });

  await grp.subscribe(MetaGetBuilder(tinode.getTopic('grpWAFkncfrJtc')).withLaterSub(null).withLaterData(null).build(), null);
  var msg = grp.createMessage('This is cool', true);
  await grp.publishMessage(msg);
}
