import 'package:tinode/src/models/topic-description.dart';
import 'package:tinode/src/models/access-mode.dart';

/// Info on when the peer was last online
class Seen {
  /// Timestamp
  DateTime? when;

  /// User agent of peer's client
  final String? ua;

  Seen({this.when, this.ua});

  static Seen fromMessages(Map<String, dynamic> msg) {
    return Seen(
      ua: msg['ua'],
      when: msg['when'] != null ? DateTime.parse(msg['when']) : DateTime.now(),
    );
  }


  Map<String, dynamic> toJson() {
    return {
      'when': when?.toIso8601String(),
      'ua': ua,
    };
  }

}

/// Topic subscriber
class TopicSubscription {
  /// Id of the user this subscription
  String? user;

  /// Timestamp of the last change in the subscription, present only for
  /// requester's own subscriptions
  DateTime? updated;

  /// Timestamp of the last message in the topic (may also include
  /// other events in the future, such as new subscribers)
  DateTime? touched;

  DateTime? deleted;
  DateTime? created;

  /// User's access permissions
  AccessMode? acs;

  /// Id of the message user claims through {note} message
  int? read;

  /// Like 'read', but received, optional
  int? recv;

  /// In case some messages were deleted, the greatest Id of a deleted message, optional
  int? clear;

  /// Application-defined user's 'public' object, absent when querying P2P topics
  dynamic public;

  /// Application-defined user's 'private' object.
  dynamic private;

  /// current online status of the user; if this is a
  /// group or a p2p topic, it's user's online status in the topic,
  /// i.e. if the user is attached and listening to messages; if this
  /// is a response to a 'me' query, it tells if the topic is
  /// online; p2p is considered online if the other party is
  /// online, not necessarily attached to topic; a group topic
  /// is considered online if it has at least one active
  /// subscriber.
  bool? online;

  /// Topic this subscription describes
  ///
  /// can be used only when querying 'me' topic
  String? topic;

  /// Server-issued id of the last {data} message
  ///
  /// can be used only when querying 'me' topic
  int? seq;

  /// If this is a P2P topic, info on when the peer was last online
  ///
  /// can be used only when querying 'me' topic
  Seen? seen;

  bool? noForwarding = false;

  String? mode;

  int? unread;

  TopicSubscription({
    this.user,
    this.updated,
    this.touched,
    this.acs,
    this.read,
    this.recv,
    this.clear,
    this.public,
    this.private,
    this.online,
    this.topic,
    this.seq,
    this.seen,
    this.noForwarding,
    this.deleted,
    this.created,
    this.mode,
    this.unread,
  });   
  
  
  Map<String, dynamic> toJson() {
    return {
      'user': user,
      'updated': updated?.toIso8601String(),
      'touched': touched?.toIso8601String(),
      'deleted': deleted?.toIso8601String(),
      'created': created?.toIso8601String(),
      'acs': acs?.toJson(),
      'read': read,
      'recv': recv,
      'clear': clear,
      'public': public,
      'private': private,
      'online': online,
      'topic': topic,
      'seq': seq,
      'seen': seen?.toJson(),
      'noForwarding': noForwarding,
      'mode': mode,
      'unread': unread,
    };
  }



  static TopicSubscription fromMessage(Map<String, dynamic> msg) {
    return TopicSubscription(
      user: msg['user'],
      updated: msg['updated'] != null ? DateTime.parse(msg['updated']) : null,
      touched: msg['touched'] != null ? DateTime.parse(msg['touched']) : null,
      deleted: msg['deleted'] != null ? DateTime.parse(msg['deleted']) : null,
      created: msg['created'] != null ? DateTime.parse(msg['created']) : null,
      acs: msg['acs'] != null ? AccessMode(msg['acs']) : null,
      read: msg['read'],
      recv: msg['recv'],
      clear: msg['clear'],
      public: msg['public'],
      private: msg['private'],
      online: msg['online'],
      topic: msg['topic'],
      seq: msg['seq'],
      seen: msg['seen'] != null ? Seen.fromMessages(msg['seen']) : null,
      noForwarding: msg['noForwarding'] ?? false,
      mode: msg['mode'],
    );
  }

  TopicSubscription copy() {
    return TopicSubscription(
      user: user,
      updated: updated,
      touched: touched,
      deleted: deleted,
      created: created,
      acs: acs,
      read: read,
      recv: recv,
      clear: clear,
      public: public,
      private: private,
      online: online,
      topic: topic,
      seq: seq,
      seen: seen,
      noForwarding: noForwarding,
      mode: mode,
    );
  }

  TopicDescription asDesc() {
    return TopicDescription(
      acs: acs,
      clear: clear,
      created: created,
      noForwarding: noForwarding,
      private: private,
      public: public,
      read: read,
      recv: recv,
      seq: seq,
      touched: touched,
      updated: updated,
    );
  }
}
