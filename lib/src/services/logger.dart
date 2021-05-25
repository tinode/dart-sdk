import 'package:tinode/src/services/configuration.dart';
import 'package:get_it/get_it.dart';

class LoggerService {
  ConfigService _configService;

  LoggerService() {
    _configService = GetIt.I.get<ConfigService>();
  }

  void error(String value) {
    if (_configService.loggerEnabled) {
      print('ERROR: ' + value);
    }
  }

  void log(String value) {
    if (_configService.loggerEnabled) {
      print('LOG: ' + value);
    }
  }

  void warn(String value) {
    if (_configService.loggerEnabled) {
      print('WARN: ' + value);
    }
  }
}
