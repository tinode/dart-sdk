import 'package:tinode/src/models/topic-subscription.dart';

class ContactUpdateEvent {
  final TopicSubscription? contact;
  final String? what;

  ContactUpdateEvent({
    this.contact,
    this.what,
  });
}
