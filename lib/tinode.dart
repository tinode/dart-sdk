library tinode;

import 'dart:async';

import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/models/connection-options.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/packet-generator.dart';
import 'package:tinode/src/services/tinode.dart';

import 'package:get_it/get_it.dart';

export 'src/models/connection-options.dart';
export 'src/models/configuration.dart';

class Tinode {
  ConfigService _configService;
  TinodeService _tinodeService;
  FutureManager _futureManager;
  LoggerService _loggerService;
  ConnectionService _connectionService;
  StreamSubscription _onMessageSubscription;
  StreamSubscription _onConnectedSubscription;

  PublishSubject<void> onConnected = PublishSubject<void>();

  Tinode(String appName, ConnectionOptions options, bool loggerEnabled) {
    _registerDependencies(options, loggerEnabled);
    _resolveDependencies();

    _configService.appName = appName;
    _doSubscriptions();
  }

  void _registerDependencies(ConnectionOptions options, bool loggerEnabled) {
    GetIt.I.registerSingleton<ConfigService>(ConfigService(loggerEnabled));
    GetIt.I.registerSingleton<LoggerService>(LoggerService());
    GetIt.I.registerSingleton<ConnectionService>(ConnectionService(options));
    GetIt.I.registerSingleton<FutureManager>(FutureManager());
    GetIt.I.registerSingleton<PacketGenerator>(PacketGenerator());
    GetIt.I.registerSingleton<TinodeService>(TinodeService());
  }

  void _resolveDependencies() {
    _configService = GetIt.I.get<ConfigService>();
    _tinodeService = GetIt.I.get<TinodeService>();
    _futureManager = GetIt.I.get<FutureManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _connectionService = GetIt.I.get<ConnectionService>();
  }

  void _doSubscriptions() {
    _onMessageSubscription ??= _connectionService.onMessage.listen((input) {
      _onConnectionMessage(input);
    });

    _onConnectedSubscription ??= _connectionService.onOpen.listen((_) {
      hello();
    });
  }

  void _unsubscribeAll() {
    _onMessageSubscription.cancel();
    _onMessageSubscription = null;
    _onConnectedSubscription.cancel();
    _onConnectedSubscription = null;
  }

  void _onConnectionMessage(String input) {
    if (input == null || input == '') {
      return;
    }

    _loggerService.log('in: ' + input);
  }

  /// Open the connection
  Future connect() {
    _doSubscriptions();
    _futureManager.startCheckingExpiredFutures();
    return _connectionService.connect();
  }

  /// Close the current connection
  void disconnect() {
    _unsubscribeAll();
    _futureManager.stopCheckingExpiredFutures();
    _connectionService.disconnect();
  }

  /// Is current connection open
  bool get isConnected {
    return _connectionService.isConnected;
  }

  /// Enable or disable logger service
  void enableLogger(bool enabled) {
    _configService.loggerEnabled = enabled;
  }

  /// Say hello and set some initial configuration like:
  /// * User agent
  /// * Device token for notifications
  /// * Language
  /// * Platform
  Future hello() {
    return _tinodeService.hello();
  }
}
