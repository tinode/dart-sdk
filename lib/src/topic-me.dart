import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/models/topic-subscription.dart';
import 'package:tinode/src/models/topic-description.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/models/credential.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/services/tools.dart';
import 'package:tinode/src/topic.dart';
import 'package:get_it/get_it.dart';
import 'package:rxdart/rxdart.dart';

class TopicMe extends Topic {
  /// List of contacts (topic_name -> Contact object)
  final Map<String, TopicSubscription> _contacts = {};

  /// This event will be triggered when a contact is updated
  PublishSubject onContactUpdate = PublishSubject<dynamic>();

  /// Tinode service, responsible for handling messages, preparing packets and sending them
  TinodeService _tinodeService;

  /// Cache manager service, responsible for read and write operations on cached data
  CacheManager _cacheManager;

  TopicMe() : super(topic_names.TOPIC_ME) {
    _cacheManager = GetIt.I.get<CacheManager>();
    _tinodeService = GetIt.I.get<TinodeService>();
  }

  @override
  void processMetaDesc(TopicDescription desc) {
    // Check if online contacts need to be turned off because P permission was removed.
    var turnOff = (desc.acs != null && !desc.acs.isPresencer(null)) && (acs != null && acs.isPresencer(null));

    // Copy parameters from desc object to this topic
    acs = desc.acs ?? acs;
    clear = desc.clear ?? clear;
    created = desc.created ?? created;
    defacs = desc.defacs ?? defacs;
    private = desc.private ?? private;
    public = desc.public ?? public;
    read = desc.read ?? read;
    recv = desc.recv ?? recv;
    seq = desc.seq ?? seq;
    status = desc.status ?? status;
    updated = desc.updated ?? updated;
    touched = desc.touched ?? touched;

    if (turnOff) {
      _contacts.forEach((key, cont) {
        if (cont.online) {
          cont.online = false;
          if (cont.seen != null) {
            cont.seen.when = DateTime.now();
          } else {
            cont.seen = Seen(when: DateTime.now());
          }
          onContactUpdate.add({'status': 'off', 'contact': cont});
        }
      });
    }

    onMetaSub.add(this);
  }

  @override
  void processMetaSub(List<TopicSubscription> subscriptions) {
    for (var sub in subscriptions) {
      var topicName = sub.topic;
      // Don't show 'me' and 'fnd' topics in the list of contacts.
      if (topicName == topic_names.TOPIC_FND || topicName == topic_names.TOPIC_ME) {
        continue;
      }

      TopicSubscription cont;
      if (sub.deleted != null) {
        _contacts.remove(topicName);
        _cacheManager.delete('topic', topicName);
      } else {
        // Ensure the values are defined and are integers.
        if (sub.seq != null) {
          sub.seq = sub.seq ?? 0;
          sub.recv = sub.recv ?? 0;
          sub.read = sub.read ?? 0;
          sub.unread = sub.seq - sub.read;
        }

        var cached = _contacts[topicName];
        cached.acs = sub.acs ?? cached.acs;
        cached.clear = sub.clear ?? cached.clear;
        cached.created = sub.created ?? cached.created;
        cached.deleted = cached.deleted ?? cached.deleted;
        cached.mode = sub.mode ?? cached.mode;
        cached.noForwarding = sub.mode ?? cached.noForwarding;
        cached.online = sub.online ?? cached.online;
        cached.private = sub.private ?? cached.private;
        cached.public = sub.public ?? cached.public;
        cached.read = sub.read ?? cached.read;
        cached.recv = sub.recv ?? cached.recv;
        cached.seen = sub.seen ?? cached.seen;
        cached.seen = sub.seen ?? cached.seen;
        cached.topic = sub.topic ?? cached.topic;
        cached.touched = sub.touched ?? cached.touched;
        cached.updated = sub.updated ?? cached.updated;
        cached.user = sub.user ?? cached.user;

        if (Tools.isP2PTopicName(topicName)) {
          _cacheManager.putUser(topicName, cont);
        }

        // Notify topic of the update if it's an external update.
        if (!sub.noForwarding) {
          var topic = _tinodeService.getTopic(topicName);
          if (topic != null) {
            sub.noForwarding = true;
            topic.processMetaDesc(sub.asDesc());
          }
        }
      }

      onMetaSub.add(cont);
    }

    onSubsUpdated.add(_contacts.values.toList());
  }

  @override
  void processMetaCreds(List<UserCredential> cred, bool update) {
    // FIXME: Implement
  }

  dynamic getContact(String a) {}
  dynamic getMsgReadRecv(String name, String what) {}
  dynamic setMsgReadRecv(String name, String what, int seq, DateTime ts) {}
}
