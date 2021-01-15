library tinode;

import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/models/account-params.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/models/connection-options.dart';
import 'package:tinode/src/services/packet-generator.dart';

import 'package:get_it/get_it.dart';
import 'package:tinode/src/topic.dart';
import 'package:tinode/src/services/tools.dart';

export 'src/models/configuration.dart';
export 'src/models/connection-options.dart';

class Tinode {
  CacheManager _cacheManager;
  ConfigService _configService;
  TinodeService _tinodeService;
  FutureManager _futureManager;
  LoggerService _loggerService;
  ConnectionService _connectionService;
  StreamSubscription _onMessageSubscription;
  StreamSubscription _onConnectedSubscription;
  StreamSubscription _onDisconnectedSubscription;

  // Event
  PublishSubject<void> onConnected = PublishSubject<void>();
  PublishSubject<void> onDisconnect = PublishSubject<void>();
  PublishSubject<void> onNetworkProbe = PublishSubject<void>();
  PublishSubject<dynamic> onMessage = PublishSubject<dynamic>();
  PublishSubject<String> onRawMessage = PublishSubject<String>();

  bool _authenticated = false;

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
    GetIt.I.registerSingleton<CacheManager>(CacheManager());
    GetIt.I.registerSingleton<TinodeService>(TinodeService());
  }

  void _resolveDependencies() {
    _configService = GetIt.I.get<ConfigService>();
    _tinodeService = GetIt.I.get<TinodeService>();
    _futureManager = GetIt.I.get<FutureManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _connectionService = GetIt.I.get<ConnectionService>();
    _cacheManager = GetIt.I.get<CacheManager>();
  }

  void _doSubscriptions() {
    _onMessageSubscription ??= _connectionService.onMessage.listen((input) {
      _onConnectionMessage(input);
    });

    _onConnectedSubscription ??= _connectionService.onOpen.listen((_) {
      hello();
    });

    _onDisconnectedSubscription ??= _connectionService.onDisconnect.listen((_) {
      _onConnectionDisconnect();
    });

    _futureManager.startCheckingExpiredFutures();
  }

  void _unsubscribeAll() {
    _onMessageSubscription.cancel();
    _onMessageSubscription = null;
    _onConnectedSubscription.cancel();
    _onConnectedSubscription = null;
    _futureManager.stopCheckingExpiredFutures();
  }

  void _onConnectionDisconnect() {
    _unsubscribeAll();
    _futureManager.rejectAllFutures(0, 'disconnect');
    _cacheManager.map((String key, dynamic value) {
      if (key.contains('topic:')) {
        Topic topic = value;
        topic.resetSub();
      }
    });
    onDisconnect.add(null);
  }

  void _onConnectionMessage(String input) {
    if (input == null || input == '') {
      return;
    }
    _loggerService.log('in: ' + input);

    // Send raw message to listener
    onRawMessage.add(input);

    if (input == '0') {
      onNetworkProbe.add(null);
    }

    var pkt = jsonDecode(input, reviver: Tools.jsonParserHelper);
    if (pkt == null) {
      _loggerService.error('failed to parse data');
      return;
    }

    // Send complete packet to listener
    onMessage.add(pkt);

    if (pkt['ctrl'] != null) {
      _tinodeService.handleCtrlMessage(pkt);
    } else if (pkt['meta'] != null) {
      _tinodeService.handleMetaMessage(pkt);
    } else if (pkt['data'] != null) {
      _tinodeService.handleDataMessage(pkt);
    } else if (pkt['pres'] != null) {
      _tinodeService.handlePresMessage(pkt);
    } else if (pkt['info'] != null) {
      _tinodeService.handleInfoMessage(pkt);
    }
  }

  String get version {
    return _configService.appVersion;
  }

  /// Open the connection
  Future connect() {
    _doSubscriptions();
    return _connectionService.connect();
  }

  /// Close the current connection
  void disconnect() {
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

  bool get isAuthenticated {
    return _authenticated;
  }

  /// Say hello and set some initial configuration like:
  /// * User agent
  /// * Device token for notifications
  /// * Language
  /// * Platform
  Future hello() {
    return _tinodeService.hello();
  }

  /// Create or update an account
  Future account(String userId, String scheme, String secret, bool login, AccountParams params) {
    return _tinodeService.account(userId, scheme, secret, login, params);
  }
}
