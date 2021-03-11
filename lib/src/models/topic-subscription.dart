import 'package:tinode/src/models/access-mode.dart';

/// Info on when the peer was last online
class Seen {
  /// Timestamp
  final DateTime when;

  /// User agent of peer's client
  final String ua;

  Seen({this.when, this.ua});

  static Seen fromMessages(Map<String, String> msg) {
    return Seen(
      ua: msg['ua'],
      when: msg['when'] != null ? DateTime.parse(msg['when']) : DateTime.now(),
    );
  }
}

/// Topic subscriber
class TopicSubscription {
  /// Id of the user this subscription
  final String user;

  /// Timestamp of the last change in the subscription, present only for
  /// requester's own subscriptions
  final DateTime updated;

  /// Timestamp of the last message in the topic (may also include
  /// other events in the future, such as new subscribers)
  final DateTime touched;

  /// User's access permissions
  final AccessMode acs;

  /// Id of the message user claims through {note} message
  final int read;

  /// Like 'read', but received, optional
  final int recv;

  /// In case some messages were deleted, the greatest Id of a deleted message, optional
  final int clear;

  /// Application-defined user's 'public' object, absent when querying P2P topics
  final dynamic public;

  /// Application-defined user's 'private' object.
  final dynamic private;

  /// current online status of the user; if this is a
  /// group or a p2p topic, it's user's online status in the topic,
  /// i.e. if the user is attached and listening to messages; if this
  /// is a response to a 'me' query, it tells if the topic is
  /// online; p2p is considered online if the other party is
  /// online, not necessarily attached to topic; a group topic
  /// is considered online if it has at least one active
  /// subscriber.
  final int online;

  /// Topic this subscription describes
  ///
  /// can be used only when querying 'me' topic
  final String topic;

  /// Server-issued id of the last {data} message
  ///
  /// can be used only when querying 'me' topic
  final int seq;

  /// If this is a P2P topic, info on when the peer was last online
  ///
  /// can be used only when querying 'me' topic
  final Seen seen;

  final bool noForwarding;

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
  });

  static TopicSubscription fromMessage(Map<String, dynamic> msg) {
    return TopicSubscription(
      user: msg['user'],
      updated: msg['updated'] != null ? DateTime.parse(msg['updated']) : DateTime.now(),
      touched: msg['touched'] != null ? DateTime.parse(msg['touched']) : DateTime.now(),
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
      noForwarding: msg['noForwarding'],
    );
  }
}
