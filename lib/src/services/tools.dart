import 'package:tinode/src/models/connection-options.dart';

var messageId = 89077;

class Tools {
  static String makeBaseURL(ConnectionOptions config) {
    var url = config.secure ? 'wss://' : 'ws://';
    return url + config.host + '/v0/channels?apikey=' + config.apiKey;
  }

  static String getNextUniqueId() {
    messageId++;
    return messageId.toString();
  }
}
