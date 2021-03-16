import 'package:tinode/src/models/credential.dart';
import 'package:tinode/src/models/topic-description.dart';
import 'package:tinode/src/models/topic-subscription.dart';

class SetParams {
  TopicDescription desc;
  TopicSubscription sub;
  List<String> tags;
  UserCredential cred;

  SetParams({this.desc, this.sub, this.tags, this.cred});
}
