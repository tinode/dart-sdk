import 'package:tinode/src/models/topic-description.dart';
import 'package:tinode/src/models/topic-subscription.dart';
import 'package:tinode/src/models/credential.dart';

class SetParams {
  TopicDescription? desc;
  TopicSubscription? sub;
  List<String>? tags;
  Credential? cred;

  SetParams({this.desc, this.sub, this.tags, this.cred});

    Map<String, dynamic> toJson(){
    return{
      'desc' : desc?.toJson(),
      'sub': sub?.toJson(),
      'tags' : tags,
      'cred': cred?.toJson(),
    };
  }

}
