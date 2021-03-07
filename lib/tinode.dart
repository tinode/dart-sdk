library tinode;

import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:get_it/get_it.dart';
import 'package:tinode/src/models/access-mode.dart';
import 'package:tinode/src/models/server-configuration.dart';

import 'package:tinode/src/models/topic-names.dart' as topic_names;
import 'package:tinode/src/models/connection-options.dart';
import 'package:tinode/src/services/packet-generator.dart';
export 'package:tinode/src/models/connection-options.dart';
import 'package:tinode/src/services/future-manager.dart';
import 'package:tinode/src/services/cache-manager.dart';
import 'package:tinode/src/services/configuration.dart';
import 'package:tinode/src/models/account-params.dart';
export 'package:tinode/src/models/configuration.dart';
import 'package:tinode/src/services/connection.dart';
import 'package:tinode/src/models/set-params.dart';
import 'package:tinode/src/models/auth-token.dart';
import 'package:tinode/src/models/del-range.dart';
import 'package:tinode/src/models/get-query.dart';
import 'package:tinode/src/services/logger.dart';
import 'package:tinode/src/services/tinode.dart';
import 'package:tinode/src/models/message.dart';
import 'package:tinode/src/services/tools.dart';
import 'package:tinode/src/services/auth.dart';
import 'package:tinode/src/topic-fnd.dart';
import 'package:tinode/src/topic-me.dart';
import 'package:tinode/src/topic.dart';

/// Provides a simple interface to interact with tinode server using websocket
class Tinode {
  /// Authentication service, responsible for managing credentials and user id
  AuthService _authService;

  /// Cache manager service, responsible for read and write operations on cached data
  CacheManager _cacheManager;

  /// Configuration service, responsible for storing library config and information
  ConfigService _configService;

  /// Tinode service, responsible for handling messages, preparing packets and sending them
  TinodeService _tinodeService;

  /// Future manager, responsible for making futures and executing them
  FutureManager _futureManager;

  /// Logger service, responsible for logging content in different levels
  LoggerService _loggerService;

  /// Connection service, responsible for establishing a websocket connection to the server
  ConnectionService _connectionService;

  /// `onMessage` subscription stored to unsubscribe later
  StreamSubscription _onMessageSubscription;

  /// `onConnected` subscription stored to unsubscribe later
  StreamSubscription _onConnectedSubscription;

  /// `onDisconnect` subscription stored to unsubscribe later
  StreamSubscription _onDisconnectedSubscription;

  /// `onConnected` event will be triggered when connection opens
  PublishSubject<void> onConnected = PublishSubject<void>();

  /// `onDisconnect` event will be triggered when connection is closed
  PublishSubject<void> onDisconnect = PublishSubject<void>();

  /// `onNetworkProbe` event will be triggered when network prob packet is received
  PublishSubject<void> onNetworkProbe = PublishSubject<void>();

  /// `onMessage` event will be triggered when a message is received
  PublishSubject<dynamic> onMessage = PublishSubject<dynamic>();

  /// `onRawMessage` event will be triggered when a message is received value will be a json
  PublishSubject<String> onRawMessage = PublishSubject<String>();

  /// Creates an instance of Tinode interface to interact with tinode server using websocket
  ///
  /// `appName` name of the client
  ///
  /// `options` connection configuration and api key
  ///
  /// `loggerEnabled` pass `true` if you want to turn the logger on
  Tinode(String appName, ConnectionOptions options, bool loggerEnabled) {
    _registerDependencies(options, loggerEnabled);
    _resolveDependencies();

    _configService.appName = appName;
    _doSubscriptions();
  }

  /// Register services in dependency injection container
  void _registerDependencies(ConnectionOptions options, bool loggerEnabled) {
    GetIt.I.registerSingleton<ConfigService>(ConfigService(loggerEnabled));
    GetIt.I.registerSingleton<LoggerService>(LoggerService());
    GetIt.I.registerSingleton<AuthService>(AuthService());
    GetIt.I.registerSingleton<ConnectionService>(ConnectionService(options));
    GetIt.I.registerSingleton<FutureManager>(FutureManager());
    GetIt.I.registerSingleton<PacketGenerator>(PacketGenerator());
    GetIt.I.registerSingleton<CacheManager>(CacheManager());
    GetIt.I.registerSingleton<TinodeService>(TinodeService());
  }

  /// Resolve dependencies from container
  void _resolveDependencies() {
    _configService = GetIt.I.get<ConfigService>();
    _tinodeService = GetIt.I.get<TinodeService>();
    _futureManager = GetIt.I.get<FutureManager>();
    _loggerService = GetIt.I.get<LoggerService>();
    _connectionService = GetIt.I.get<ConnectionService>();
    _cacheManager = GetIt.I.get<CacheManager>();
    _authService = GetIt.I.get<AuthService>();
  }

  /// Subscribe to needed events like connection
  void _doSubscriptions() {
    _onMessageSubscription ??= _connectionService.onMessage.listen((input) {
      _onConnectionMessage(input);
    });

    _onConnectedSubscription ??= _connectionService.onOpen.listen((_) {
      _futureManager.checkExpiredFutures();
      onConnected.add(null);
    });

    _onDisconnectedSubscription ??= _connectionService.onDisconnect.listen((_) {
      _onConnectionDisconnect();
    });

    _futureManager.startCheckingExpiredFutures();
  }

  /// Unsubscribe every subscription to prevent memory leak
  void _unsubscribeAll() {
    _onMessageSubscription.cancel();
    _onMessageSubscription = null;
    _onConnectedSubscription.cancel();
    _onConnectedSubscription = null;
    _futureManager.stopCheckingExpiredFutures();
  }

  /// Unsubscribe and reset local variables when connection closes
  void _onConnectionDisconnect() {
    _unsubscribeAll();
    _futureManager.rejectAllFutures(0, 'disconnect');
    _cacheManager.map((String key, dynamic value) {
      if (key.contains('topic:')) {
        Topic topic = value;
        topic.resetSubscription();
      }
    });
    onDisconnect.add(null);
  }

  /// Handler for newly received messages from server
  void _onConnectionMessage(String input) {
    if (input == null || input == '') {
      return;
    }
    _loggerService.log('in: ' + input);

    // Send raw message to listener
    onRawMessage.add(input);

    if (input == '0') {
      onNetworkProbe.add(null);
      return;
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

  /// Open the connection and send a hello packet to server
  Future connect() async {
    _doSubscriptions();
    await _connectionService.connect();
    return hello();
  }

  /// Close the current connection
  void disconnect() {
    _connectionService.disconnect();
  }

  /// Send a network probe message to make sure the connection is alive
  void networkProbe() {
    _connectionService.probe();
  }

  /// Is current connection open
  bool get isConnected {
    return _connectionService.isConnected;
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
  Future hello({String deviceToken}) async {
    var ctrl;
    if (deviceToken != null) {
      ctrl = await _tinodeService.hello(deviceToken: deviceToken);
    } else {
      ctrl = await _tinodeService.hello();
    }
    _configService.setServerConfiguration(ctrl['params']);
    return ctrl;
  }

  /// Wrapper for `hello`, sends hi packet again containing device token
  Future setDeviceToken(String deviceToken) {
    return hello(deviceToken: deviceToken);
  }

  /// Create or update an account
  ///
  /// * Scheme can be `basic` or `token` or `reset`
  Future account(String userId, String scheme, String secret, bool login, AccountParams params) {
    return _tinodeService.account(userId, scheme, secret, login, params);
  }

  /// Create a new user. Wrapper for `account` method
  Future createAccount(String scheme, String secret, bool login, AccountParams params) {
    var promise = account(topic_names.USER_NEW, scheme, secret, login, params);
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

  /// Update account with basic
  Future updateAccountBasic(String userId, String username, String password, AccountParams params) {
    username ??= '';
    username ??= '';
    var secret = base64.encode(utf8.encode(username + ':' + password));
    return account(userId, 'basic', secret, false, params);
  }

  /// Authenticate current session
  Future login(String scheme, String secret, Map<String, dynamic> cred) {
    return _tinodeService.login(scheme, secret, cred);
  }

  /// Wrapper for `login` with basic authentication
  Future loginBasic(String username, String password, Map<String, dynamic> cred) async {
    var secret = base64.encode(utf8.encode(username + ':' + password));
    var ctrl = await login('basic', secret, cred);
    _authService.setLastLogin(username);
    return ctrl;
  }

  /// Wrapper for `login` with token authentication
  Future loginToken(String token, Map<String, dynamic> cred) {
    return login('token', token, cred);
  }

  /// Send a request for resetting an authentication secret
  /// * scheme - authentication scheme to reset ex: `basic`
  /// * method - method to use for resetting the secret, such as "email" or "tel"
  /// * value - value of the credential to use, a specific email address or a phone number
  Future requestResetSecret(String scheme, String method, String value) {
    var secret = base64.encode(utf8.encode(scheme + ':' + method + ':' + value));
    return login('reset', secret, null);
  }

  /// Get stored authentication token
  AuthToken getAuthenticationToken() {
    return _authService.authToken;
  }

  /// Send a topic subscription request
  Future subscribe(String topicName, GetQuery getParams, SetParams setParams) {
    return _tinodeService.subscribe(topicName, getParams, setParams);
  }

  /// Detach and optionally unsubscribe from the topic
  Future leave(String topicName, bool unsubscribe) {
    return _tinodeService.leave(topicName, unsubscribe);
  }

  /// Create message draft without sending it to the server
  Message createMessage(String topicName, dynamic data, bool echo) {
    return _tinodeService.createMessage(topicName, data, echo);
  }

  /// Publish message to topic. The message should be created by `createMessage`
  Future publishMessage(Message message) {
    return _tinodeService.publishMessage(message);
  }

  /// Request topic metadata
  Future getMeta(String topicName, GetQuery params) {
    return _tinodeService.getMeta(topicName, params);
  }

  /// Update topic's metadata: description, subscriptions
  Future setMeta(String topicName, SetParams params) {
    return _tinodeService.setMeta(topicName, params);
  }

  /// Delete some or all messages in a topic
  Future deleteMessages(String topicName, List<DelRange> ranges, bool hard) {
    return _tinodeService.deleteMessages(topicName, ranges, hard);
  }

  /// Delete the topic all together. Requires Owner permission
  Future deleteTopic(String topicName, bool hard) {
    return _tinodeService.deleteTopic(topicName, hard);
  }

  /// Delete subscription. Requires Share permission
  Future deleteSubscription(String topicName, String userId) {
    return _tinodeService.deleteSubscription(topicName, userId);
  }

  /// Delete credential. Always sent on 'me' topic
  Future deleteCredential(String method, String value) {
    return _tinodeService.deleteCredential(method, userId);
  }

  /// Request to delete account of the current user
  Future deleteCurrentUser(bool hard) async {
    var ctrl = _tinodeService.deleteCurrentUser(hard);
    _authService.setUserId(null);
    return ctrl;
  }

  /// Notify server that a message or messages were read or received. Does NOT return promise
  void note(String topicName, String what, int seq) {
    _tinodeService.note(topicName, what, seq);
  }

  /// Broadcast a key-press notification to topic subscribers. Used to show
  /// typing notifications "user X is typing..."
  void noteKeyPress(String topicName) async {
    await _tinodeService.noteKeyPress(topicName);
  }

  /// Get a named topic, either pull it from cache or create a new instance
  /// There is a single instance of topic for each name
  Topic getTopic(String topicName) {
    return _tinodeService.getTopic(topicName);
  }

  /// Check if named topic is already present in cache
  bool isTopicCached(String topicName) {
    var topic = _cacheManager.get('topic', topicName);
    return topic != null;
  }

  /// Instantiate a new group topic. An actual name will be assigned by the server
  Topic newTopic() {
    return _tinodeService.newTopic();
  }

  /// Instantiate a new channel-enabled group topic. An actual name will be assigned by the server
  Topic newChannel() {
    return _tinodeService.newTopic();
  }

  /// Generate unique name like 'new123456' suitable for creating a new group topic
  String newGroupTopicName(bool isChan) {
    return _tinodeService.newGroupTopicName(isChan);
  }

  /// Instantiate a new P2P topic with a given peer
  Topic newTopicWith(String peerUserId) {
    return _tinodeService.newTopicWith(peerUserId);
  }

  /// Instantiate 'me' topic or get it from cache
  TopicMe getMeTopic() {
    return _tinodeService.getTopic(topic_names.TOPIC_ME);
  }

  /// Instantiate 'fnd' (find) topic or get it from cache
  TopicFnd getFndTopic() {
    return _tinodeService.getTopic(topic_names.TOPIC_FND);
  }

  /// Get the user id of the the current authenticated user
  String getCurrentUserId() {
    return _authService.userId;
  }

  /// Check if the given user ID is equal to the current user's user id
  bool isMe(String userId) {
    return _authService.userId == userId;
  }

  /// Get login (user id) used for last successful authentication.
  String getCurrentLogin() {
    return _authService.lastLogin;
  }

  /// Return information about the server: protocol, version, limits, and build timestamp
  ServerConfiguration getServerInfo() {
    return _configService.serverConfiguration;
  }

  /// Enable or disable logger service
  void enableLogger(bool enabled) {
    _configService.loggerEnabled = enabled;
  }

  /// Set UI language to report to the server. Must be called before 'hi' is sent, otherwise it will not be used
  void setHumanLanguage(String language) {
    _configService.humanLanguage = language;
  }

  /// Check if given topic is online
  bool isTopicOnline(String topicName) {
    // TODO: Needs implementation of me topic
    return false;
  }

  /// Get access mode for the given contact
  AccessMode getTopicAccessMode() {
    // TODO: Needs implementation of me topic
    return AccessMode('');
  }
}
