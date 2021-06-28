import 'package:tinode/src/models/access-mode.dart';
import 'package:tinode/src/models/def-acs.dart';

class TopicDescription {
  /// Topic creation date
  final DateTime? created;

  /// Topic update date
  DateTime? updated;

  /// Topic touched date
  final DateTime? touched;

  /// account status; included for `me` topic only, and only if
  /// the request is sent by a root-authenticated session.
  final String? status;

  /// topic's default access permissions; present only if the current user has 'S' permission
  DefAcs? defacs;

  /// Actual access permissions
  AccessMode? acs;

  /// Server-issued id of the last {data} message
  final int? seq;

  /// Id of the message user claims through {note} message to have read, optional
  final int? read;

  /// Like 'read', but received, optional
  final int? recv;

  /// in case some messages were deleted, the greatest ID
  /// of a deleted message, optional
  final int? clear;

  /// Application-defined data that's available to all topic subscribers
  dynamic public;

  /// Application-defined data that's available to the current user only
  dynamic private;

  bool? noForwarding;

  TopicDescription({
    this.created,
    this.updated,
    this.status,
    this.defacs,
    this.acs,
    this.seq,
    this.read,
    this.recv,
    this.clear,
    this.public,
    this.private,
    this.noForwarding,
    this.touched,
  });

  Map<String, dynamic> toJson() {
    return {
      'created': created?.toIso8601String(),
      'updated': updated?.toIso8601String(),
      'touched': touched?.toIso8601String(),
      'status': status,
      'defacs': defacs?.toJson(),
      'acs': acs?.jsonHelper(),
      'seq': seq,
      'read': read,
      'recv': recv,
      'clear': clear,
      'public': public,
      'private': private,
    };
  }

  /// Create a new instance from received message
  static TopicDescription fromMessage(Map<String, dynamic> msg) {
    return TopicDescription(
      created: msg['created'] != null ? DateTime.parse(msg['created']) : DateTime.now(),
      updated: msg['updated'] != null ? DateTime.parse(msg['updated']) : DateTime.now(),
      acs: msg['acs'] != null ? AccessMode(msg['acs']) : null,
      public: msg['public'],
      private: msg['private'],
      status: msg['status'],
      defacs: msg['defacs'] != null ? DefAcs.fromMessage(msg['defacs']) : null,
      seq: msg['seq'],
      read: msg['read'],
      recv: msg['recv'],
      clear: msg['clear'],
      noForwarding: msg['noForwarding'],
      touched: msg['touched'],
    );
  }
}
