import 'package:get_it/get_it.dart';
import 'dart:async';

import 'package:tinode/src/models/future-callback.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/logger.dart';

class FutureManager {
  final Map<String, FutureCallback> _pendingFutures = {};
  Timer? _expiredFuturesCheckerTimer;
  late ConfigService _configService;
  late LoggerService _loggerService;

  FutureManager() {
    _configService = GetIt.I.get<ConfigService>();
    _loggerService = GetIt.I.get<LoggerService>();
  }

  Future<dynamic> makeFuture(String id) {
    var completer = Completer();
    if (id != null) {
      _pendingFutures[id] = FutureCallback(completer: completer, ts: DateTime.now());
    }
    return completer.future;
  }

  void execFuture(String? id, int code, dynamic onOK, String? errorText) {
    var callbacks = _pendingFutures[id];

    if (callbacks != null) {
      _pendingFutures.remove(id);
      if (code >= 200 && code < 400) {
        callbacks.completer?.complete(onOK);
      } else {
        callbacks.completer?.completeError(Exception((errorText ?? '') + ' (' + code.toString() + ')'));
      }
    }
  }

  void checkExpiredFutures() {
    var exception = Exception('Timeout (504)');
    var expires = DateTime.now().subtract(Duration(milliseconds: _configService.appSettings.expireFuturesTimeout));

    var markForRemoval = <String>[];
    _pendingFutures.forEach((String key, FutureCallback featureCB) {
      if (featureCB.ts!.isBefore(expires)) {
        _loggerService.error('Promise expired ' + key.toString());
        featureCB.completer?.completeError(exception);
        markForRemoval.add(key);
      }
    });

    _pendingFutures.removeWhere((key, value) => markForRemoval.contains(key));
  }

  void startCheckingExpiredFutures() {
    if (_expiredFuturesCheckerTimer != null && _expiredFuturesCheckerTimer!.isActive) {
      return;
    }
    _expiredFuturesCheckerTimer = Timer.periodic(Duration(milliseconds: _configService.appSettings.expireFuturesPeriod), (_) {
      checkExpiredFutures();
    });
  }

  void rejectAllFutures(int code, String reason) {
    _pendingFutures.forEach((String key, FutureCallback cb) {
      cb.completer?.completeError(reason);
    });
  }

  void stopCheckingExpiredFutures() {
    if (_expiredFuturesCheckerTimer != null) {
      _expiredFuturesCheckerTimer?.cancel();
      _expiredFuturesCheckerTimer = null;
    }
  }
}
