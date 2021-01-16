library tinode;

import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:tinode/src/models/auth-token.dart';
import 'package:tinode/src/services/auth.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/models/account-params.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/models/connection-options.dart';
import 'package:tinode/src/services/packet-generator.dart';
import 'package:tinode/src/models/topic-names.dart' as TopicNames;

import 'package:get_it/get_it.dart';
import 'package:tinode/src/topic.dart';
import 'package:tinode/src/services/tools.dart';

export 'src/models/configuration.dart';
export 'src/models/connection-options.dart';

class Tinode {
  AuthService _authService;
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
    GetIt.I.registerSingleton<AuthService>(AuthService());
    GetIt.I.registerSingleton<TinodeService>(TinodeService());
  }

  void _resolveDependencies() {
    _configService = GetIt.I.get<ConfigService>();
    _tinodeService = GetIt.I.get<TinodeService>();
    _futureManager = GetIt.I.get<FutureManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _connectionService = GetIt.I.get<ConnectionService>();
    _cacheManager = GetIt.I.get<CacheManager>();
    _authService = GetIt.I.get<AuthService>();
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

  /// Specifies if user is authenticated
  bool get isAuthenticated {
    return _authService.isAuthenticated;
  }

  /// Current user token
  AuthToken get token {
    return _authService.authToken;
  }

  /// Current user id
  String get userId {
    return _authService.userId;
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
  ///
  /// * Scheme can be `basic` or `token` or `reset`
  Future account(String userId, String scheme, String secret, bool login, AccountParams params) {
    return _tinodeService.account(userId, scheme, secret, login, params);
  }

  /// Create a new user. Wrapper for `account` method.
  Future createAccount(String scheme, String secret, bool login, AccountParams params) {
    var promise = account(TopicNames.USER_NEW, scheme, secret, login, params);
    if (login) {
      promise = promise.then((dynamic ctrl) {
        _authService.onLoginSuccessful(ctrl);
        return ctrl;
      });
    }
    return promise;
  }

  /// Create user with 'basic' authentication scheme and immediately
  /// use it for authentication. Wrapper for `createAccount`
  Future createAccountBasic(String username, String password, bool login, AccountParams params) {
    username ??= '';
    username ??= '';
    var secret = base64.encode(utf8.encode(username + ':' + password));
    return createAccount('basic', secret, login, params);
  }
}
