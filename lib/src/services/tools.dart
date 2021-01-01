import 'package:tinode/src/models/access-mode.dart';
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

  static dynamic jsonParserHelper(key, value) {
    if (key == 'ts' && value is String && value.length >= 20 && value.length <= 24) {
      var date = DateTime.parse(value);
      return date;
    } else if (key == 'acs' && value is Map) {
      return AccessMode(value);
    }
    return value;
  }
}
