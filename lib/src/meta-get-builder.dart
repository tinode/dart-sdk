import 'package:get_it/get_it.dart';

import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/models/topic-subscription.dart';
import 'package:tinode/src/models/get-query.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/topic-me.dart';
import 'package:tinode/src/topic.dart';

class MetaGetBuilder {
  /// Tinode service, responsible for handling messages, preparing packets and sending them
  late TinodeService _tinodeService;

  /// Logger service, responsible for logging content in different levels
  late LoggerService _loggerService;

  late Topic topic;
  TopicSubscription? contact;
  Map<String, dynamic> what = {};

  MetaGetBuilder(Topic parent) {
    _tinodeService = GetIt.I.get<TinodeService>();
    _loggerService = GetIt.I.get<LoggerService>();

    topic = parent;
    var me = _tinodeService.getTopic(topic_names.TOPIC_ME) as TopicMe?;

    if (me != null) {
      if (parent.name != null) {
        contact = me.getContact(parent.name!);
      }
    }
  }

  /// Get latest timestamp
  DateTime _getIms() {
    var cupd = contact != null ? contact?.updated : null;
    var tupd = topic.lastDescUpdate;
    return tupd.isAfter(cupd!) ? cupd : tupd;
  }

  /// Add query parameters to fetch messages within explicit limits
  MetaGetBuilder withData(int? since, int? before, int? limit) {
    what['data'] = {'since': since, 'before': before, 'limit': limit};
    return this;
  }

  /// Add query parameters to fetch messages newer than the latest saved message
  MetaGetBuilder withLaterData(int? limit) {
    if (topic.maxSeq <= 0) {
      return this;
    }

    return withData((topic.maxSeq > 0 ? topic.maxSeq + 1 : null)!, null, limit);
  }

  /// Add query parameters to fetch messages older than the earliest saved message
  MetaGetBuilder withEarlierData(int limit) {
    return withData(null, (topic.minSeq > 0 ? topic.minSeq : null)!, limit);
  }

  /// Add query parameters to fetch topic description if it's newer than the given timestamp
  MetaGetBuilder withDesc(DateTime? ims) {
    what['desc'] = {'ims': ims};
    return this;
  }

  /// Add query parameters to fetch topic description if it's newer than the last update
  MetaGetBuilder withLaterDesc() {
    return withDesc(_getIms());
  }

  /// Add query parameters to fetch subscriptions
  MetaGetBuilder withSub(DateTime? ims, int? limit, String? userOrTopic) {
    var opts = {'ims': ims, 'limit': limit};
    if (topic.getType() == 'me') {
      opts['topic'] = userOrTopic;
    } else {
      opts['user'] = userOrTopic;
    }
    what['sub'] = opts;
    return this;
  }

  /// Add query parameters to fetch a single subscription
  MetaGetBuilder withOneSub(DateTime? ims, String? userOrTopic) {
    return withSub(ims, null, userOrTopic);
  }

  /// Add query parameters to fetch a single subscription if it's been updated since the last update
  MetaGetBuilder withLaterOneSub(String? userOrTopic) {
    return withOneSub(topic.lastSubsUpdate, userOrTopic);
  }

  /// Add query parameters to fetch subscriptions updated since the last update
  MetaGetBuilder withLaterSub(int? limit) {
    var ims = topic.isP2P() ? _getIms() : topic.lastSubsUpdate;
    return withSub(ims, limit, null);
  }

  /// Add query parameters to fetch topic tags
  MetaGetBuilder withTags() {
    what['tags'] = true;
    return this;
  }

  /// Add query parameters to fetch user's credentials. 'me' topic only
  MetaGetBuilder withCred() {
    if (topic.getType() == 'me') {
      what['cred'] = true;
    } else {
      _loggerService.error('Invalid topic type for MetaGetBuilder:withCreds ' + topic.getType().toString());
    }
    return this;
  }

  /// Add query parameters to fetch deleted messages within explicit limits. Any/all parameters can be null
  MetaGetBuilder withDel(int? since, int? limit) {
    if (since != null || limit != null) {
      what['del'] = {'since': since, 'limit': limit};
    }
    return this;
  }

  /// Add query parameters to fetch messages deleted after the saved 'del' id
  MetaGetBuilder withLaterDel(int limit) {
    // Specify 'since' only if we have already received some messages. If
    // we have no locally cached messages then we don't care if any messages were deleted.
    return withDel((topic.maxSeq > 0 ? topic.maxDel + 1 : null)!, limit);
  }

  /// Construct parameters
  GetQuery build() {
    var what = [];
    Map<String, dynamic>? params = <String, dynamic>{};
    ['data', 'sub', 'desc', 'tags', 'cred', 'del'].forEach((key) {
      if (this.what.containsKey(key)) {
        what.add(key);
        if (this.what[key].length > 0) {
          params![key] = this.what[key];
        }
      }
    });
    if (what.isNotEmpty) {
      params['what'] = what.join(' ');
    } else {
      params = null;
    }
    return GetQuery.fromMessage(params ?? {});
  }
}
