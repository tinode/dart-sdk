import 'package:tinode/src/services/configuration.dart';
import 'package:get_it/get_it.dart';

class LoggerService {
  late ConfigService _configService;

  LoggerService() {
    _configService = GetIt.I.get<ConfigService>();
  }

  void error(String value) {
    if (_configService.loggerEnabled == true) {
      print('ERROR: ' + value);
    }
  }

  void log(String value) {
    if (_configService.loggerEnabled == true) {
      print('LOG: ' + value);
    }
  }

  void warn(String value) {
    if (_configService.loggerEnabled == true) {
      print('WARN: ' + value);
    }
  }
}
