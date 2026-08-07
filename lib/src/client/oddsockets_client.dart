import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/oddsockets_config.dart';
import '../enhanced_features.dart';
import '../models/message.dart';
import '../models/types.dart';
import '../exceptions/oddsockets_exception.dart';
import '../services/manager_discovery.dart';
import '../services/message_size_validator.dart';

part 'oddsockets_channel.dart';

/// Type definition for message handlers
typedef MessageHandler = void Function(Message message);

/// Type definition for event handlers
typedef EventHandler = void Function(EventType event, Map<String, dynamic>? data);

/// Main OddSockets client for real-time messaging.
///
/// This client handles connection management, worker assignment, and provides
/// access to channels for publishing and subscribing to messages.
class OddSocketsClient {
  /// The configuration for this client
  final OddSocketsConfig config;

  /// HTTP client for REST operations
  late final Dio _dio;

  /// Logger instance
  late final Logger _logger;

  /// WebSocket connection
  WebSocketChannel? _webSocket;

  /// Current connection state
  final BehaviorSubject<ConnectionState> _connectionStateSubject = 
      BehaviorSubject<ConnectionState>.seeded(ConnectionState.disconnected);

  /// Stream of incoming messages
  final PublishSubject<Message> _messageSubject = PublishSubject<Message>();

  /// Stream of connection events
  final PublishSubject<Map<String, dynamic>> _eventSubject = PublishSubject<Map<String, dynamic>>();

  /// Map of active channels
  final Map<String, OddSocketsChannel> _channels = {};

  /// Current worker URL
  String? _workerUrl;

  /// Current worker ID
  String? _workerId;

  /// Client identifier for session stickiness
  late final String _clientIdentifier;

  /// Session information
  Map<String, dynamic>? _sessionInfo;

  /// Reconnection timer
  Timer? _reconnectTimer;

  /// Heartbeat timer
  Timer? _heartbeatTimer;

  /// Current reconnection attempt count
  int _reconnectAttempts = 0;

  /// Whether the client is disposed
  bool _disposed = false;

  /// Connectivity subscription
  StreamSubscription<ConnectivityResult>? _connectivitySubscription;

  /// Pending server responses, keyed by "responseEvent:channel".
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};

  /// Completes once the Socket.IO handshake (Engine.IO OPEN + CONNECT ack) lands.
  Completer<void>? _socketConnected;

  /// Persistent listeners for raw Socket.IO events, keyed by event name.
  final Map<String, List<Function>> _listeners = {};

  /// One-shot listeners, cleared after their first dispatch.
  final Map<String, List<Function>> _onceListeners = {};

  /// Slack-like enhanced features (reactions, typing, threads, DMs, presence,
  /// notifications, search) over the same live Socket.IO connection.
  late final EnhancedFeatures enhanced;

  /// Creates a new OddSockets client.
  OddSocketsClient(this.config) {
    enhanced = EnhancedFeatures(this);
    _initializeClient();
  }

  /// Emits a raw Socket.IO event to the worker (fire-and-forget).
  ///
  /// Used by [enhanced] for the Slack-like action surface. Null-valued keys are
  /// pruned because the worker destructures option objects and treats JSON null
  /// differently from an absent key.
  void emit(String event, Map<String, dynamic> payload) {
    if (_webSocket == null) return;
    final pruned = _pruneNulls(Map<String, dynamic>.from(payload));
    _webSocket!.sink.add('42${jsonEncode([event, pruned])}');
  }

  /// Registers a persistent listener for a raw Socket.IO event.
  void on(String event, Function handler) {
    _listeners.putIfAbsent(event, () => []).add(handler);
  }

  /// Registers a one-shot listener, removed after it fires once.
  void once(String event, Function handler) {
    _onceListeners.putIfAbsent(event, () => []).add(handler);
  }

  /// Removes a previously registered listener (or all listeners for an event).
  void off(String event, [Function? handler]) {
    if (handler == null) {
      _listeners.remove(event);
      _onceListeners.remove(event);
      return;
    }
    _listeners[event]?.remove(handler);
    _onceListeners[event]?.remove(handler);
  }

  /// Dispatches a decoded event to any registered on()/once() listeners.
  void _dispatchListeners(String event, dynamic payload) {
    final persistent = _listeners[event];
    if (persistent != null) {
      for (final handler in List<Function>.of(persistent)) {
        _invokeListener(handler, payload);
      }
    }
    final onceList = _onceListeners.remove(event);
    if (onceList != null) {
      for (final handler in onceList) {
        _invokeListener(handler, payload);
      }
    }
  }

  void _invokeListener(Function handler, dynamic payload) {
    try {
      handler(payload);
    } catch (error) {
      _logger.e('Listener for event threw', error: error);
    }
  }

  /// Current connection state
  ConnectionState get connectionState => _connectionStateSubject.value;

  /// Stream of connection state changes
  Stream<ConnectionState> get connectionStateStream => _connectionStateSubject.stream;

  /// Stream of incoming messages
  Stream<Message> get messageStream => _messageSubject.stream;

  /// Stream of connection events
  Stream<Map<String, dynamic>> get eventStream => _eventSubject.stream;

  /// Whether the client is currently connected
  bool get isConnected => connectionState.isConnected;

  /// Whether the client is currently connecting
  bool get isConnecting => connectionState.isConnecting;

  /// Whether the client is disconnected
  bool get isDisconnected => connectionState.isDisconnected;

  void _initializeClient() {
    // Generate client identifier for session stickiness
    _clientIdentifier = _generateClientIdentifier();

    // Initialize HTTP client
    _dio = Dio(BaseOptions(
      connectTimeout: config.timeout,
      receiveTimeout: config.timeout,
      sendTimeout: config.timeout,
      headers: {
        'User-Agent': Constants.userAgent,
        'Authorization': 'Bearer ${config.apiKey}',
      },
    ));

    // Initialize logger
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 0,
        errorMethodCount: 5,
        lineLength: 50,
        colors: true,
        printEmojis: true,
      ),
    );

    // Monitor connectivity changes. The connectivity_plus plugin relies on a
    // platform channel that is absent in headless/non-Flutter runtimes (flutter
    // test, servers). Touching its EventChannel there throws "Binding has not
    // yet been initialized" from the stream's lifecycle callbacks - an uncaught
    // zone error that a try/catch around .listen cannot intercept. Gate the whole
    // subscription on binding availability so the channel is never touched.
    if (_flutterBindingAvailable) {
      try {
        _connectivitySubscription = Connectivity()
            .onConnectivityChanged
            .listen(_onConnectivityChanged, onError: (_) {});
      } catch (_) {
        // Connectivity monitoring unavailable - continue without it.
      }
    }

    // Auto-connect if configured
    if (config.autoConnect) {
      connect();
    }
  }

  /// Whether a Flutter binding is initialized in the current runtime.
  ///
  /// Platform-channel plugins (connectivity_plus) require a binding; it is
  /// absent under `flutter test` and on plain Dart servers. Reading
  /// [ServicesBinding.instance] throws when no binding exists.
  bool get _flutterBindingAvailable {
    try {
      ServicesBinding.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Connects to OddSockets.
  Future<void> connect() async {
    if (_disposed) {
      throw const InvalidConfigurationException(message: 'Client has been disposed');
    }

    if (isConnecting || isConnected) {
      _logger.w('Already connected or connecting');
      return;
    }

    _updateConnectionState(ConnectionState.connecting);
    _logger.i('Connecting to OddSockets...');

    try {
      // Validate configuration
      config.validate();

      // Get worker assignment
      await _assignWorker();

      // Connect to WebSocket
      await _connectWebSocket();

      // Start heartbeat
      _startHeartbeat();

      // Reset reconnection attempts
      _reconnectAttempts = 0;

      _updateConnectionState(ConnectionState.connected);
      _logger.i('Connected to OddSockets successfully');

      // Emit connected event
      _eventSubject.add({
        'type': EventType.connected.name,
        'timestamp': DateTime.now().toIso8601String(),
        'workerUrl': _workerUrl,
      });

    } catch (error, stackTrace) {
      _logger.e('Connection failed', error: error, stackTrace: stackTrace);
      _updateConnectionState(ConnectionState.failed);

      // Emit error event
      _eventSubject.add({
        'type': EventType.error.name,
        'error': error.toString(),
        'timestamp': DateTime.now().toIso8601String(),
      });

      // Schedule reconnection if configured
      if (_shouldReconnect()) {
        _scheduleReconnect();
      }

      rethrow;
    }
  }

  /// Disconnects from OddSockets.
  Future<void> disconnect() async {
    _logger.i('Disconnecting from OddSockets...');

    // Cancel timers
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    // Close WebSocket
    await _webSocket?.sink.close();
    _webSocket = null;

    // Fail any in-flight requests and reset handshake state.
    for (final completer in _pending.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          const ConnectionException(message: 'Disconnected'),
        );
      }
    }
    _pending.clear();
    _socketConnected = null;

    // Clear worker URL
    _workerUrl = null;

    // Update state
    _updateConnectionState(ConnectionState.disconnected);

    // Emit disconnected event
    _eventSubject.add({
      'type': EventType.disconnected.name,
      'timestamp': DateTime.now().toIso8601String(),
    });

    _logger.i('Disconnected from OddSockets');
  }

  /// Gets or creates a channel with the given name.
  OddSocketsChannel channel(String name) {
    if (name.isEmpty) {
      throw InvalidChannelNameException(channelName: name);
    }

    return _channels.putIfAbsent(name, () => OddSocketsChannel(name, this));
  }

  /// Publishes multiple messages in bulk.
  ///
  /// Per-message rejections come back in the returned results. An
  /// operation-level failure - auth rejected, connection dropped, the worker
  /// refusing the batch - is thrown instead, because reporting it as N failed
  /// messages makes it indistinguishable from N individually rejected messages.
  Future<List<BulkResult>> publishBulk(List<BulkMessage> messages) async {
    if (!isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    if (messages.isEmpty) {
      return [];
    }

    final payload = {
      'type': 'bulk_publish',
      'messages': messages.map((m) => m.toJson()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    };

    final Map<String, dynamic> response;
    try {
      response = await _sendMessage(payload);
    } catch (error) {
      _logger.e('Bulk publish failed', error: error);
      rethrow;
    }

    if (response['success'] == true && response['results'] is List) {
      return (response['results'] as List)
          .map((result) => BulkResult.fromJson(result as Map<String, dynamic>))
          .toList();
    }

    final failure = MessageDeliveryException(
      message: 'Bulk publish failed: ${response['error'] ?? 'Unknown error'}',
    );
    _logger.e('Bulk publish failed', error: failure);
    throw failure;
  }

  /// Maps a client operation to the Socket.IO event the worker replies with.
  static const Map<String, String> _responseEventFor = {
    'subscribe': 'subscribed',
    'unsubscribe': 'unsubscribed',
    'publish': 'published',
    'get_presence': 'presence',
    'get_history': 'history',
  };

  /// Emits a Socket.IO event to the worker and awaits its correlated reply.
  ///
  /// The worker speaks genuine Socket.IO: each operation emits an event and the
  /// worker answers with a distinct response event (subscribe->subscribed,
  /// publish->published, ...). We correlate on "responseEvent:channel".
  Future<Map<String, dynamic>> _sendMessage(Map<String, dynamic> message) async {
    if (_webSocket == null) {
      throw const ConnectionException(message: 'WebSocket not connected');
    }

    final type = message['type'] as String;
    final responseEvent = _responseEventFor[type];
    if (responseEvent == null) {
      throw MessageDeliveryException(message: 'Unsupported operation: $type');
    }

    final channelName = message['channel'] as String?;
    final payload = _buildEventPayload(type, message);
    final key = '$responseEvent:${channelName ?? ''}';

    final completer = Completer<Map<String, dynamic>>();
    _pending[key] = completer;

    Timer(config.timeout, () {
      if (!completer.isCompleted) {
        _pending.remove(key);
        completer.completeError(OperationTimeoutException(
          operation: type,
          timeout: config.timeout,
        ));
      }
    });

    try {
      // Socket.IO EVENT packet: "42" + ["event", payload]
      _webSocket!.sink.add('42${jsonEncode([type, payload])}');
    } catch (error) {
      _pending.remove(key);
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    return completer.future;
  }

  /// Builds the worker-shaped payload for an operation, omitting null-valued
  /// keys. The worker destructures `options = {}` (only defaults on undefined,
  /// not JSON null), so sending null options crashes it - prune nulls instead.
  Map<String, dynamic> _buildEventPayload(String type, Map<String, dynamic> message) {
    final payload = <String, dynamic>{};
    if (message['channel'] != null) {
      payload['channel'] = message['channel'];
    }

    switch (type) {
      case 'publish':
        payload['message'] = message['message'];
        final opts = message['options'];
        if (opts is Map && opts.isNotEmpty) {
          payload['options'] = _pruneNulls(Map<String, dynamic>.from(opts));
        }
        break;
      case 'subscribe':
      case 'get_history':
        final opts = message['options'];
        if (opts is Map && opts.isNotEmpty) {
          payload['options'] = _pruneNulls(Map<String, dynamic>.from(opts));
        }
        break;
      case 'get_presence':
      case 'unsubscribe':
        break;
    }
    return payload;
  }

  Map<String, dynamic> _pruneNulls(Map<String, dynamic> map) {
    map.removeWhere((key, value) => value == null);
    return map;
  }

  /// Assigns a worker for this client.
  Future<void> _assignWorker() async {
    // Resolve the manager the caller asked for. Whatever comes back is the only
    // endpoint contacted - a wrong or unreachable manager must surface, not be
    // papered over with the production default.
    final managerUrl = ManagerDiscovery.resolveManagerUrl(config.managerUrl);

    try {
      final response = await _dio.get(
        '$managerUrl/api/cluster/select-worker',
        queryParameters: {
          'apiKey': config.apiKey,
          'userId': config.userId ?? _clientIdentifier,
          'clientIdentifier': _clientIdentifier,
        },
        options: Options(
          headers: {
            'User-Agent': 'OddSockets-Flutter-SDK/1.0.0',
          },
        ),
      );

      if (response.statusCode == 200 && response.data['url'] != null) {
        _workerUrl = response.data['url'] as String;
        _workerId = response.data['workerId'] as String?;
        _sessionInfo = response.data['session'] as Map<String, dynamic>?;
        
        _logger.i('Assigned to worker: $_workerUrl');

        // Emit worker assigned event
        _eventSubject.add({
          'type': EventType.workerAssigned.name,
          'workerId': _workerId,
          'workerUrl': _workerUrl,
          'session': _sessionInfo,
          'clientIdentifier': _clientIdentifier,
          'managerUrl': managerUrl, // The manager actually used, for debugging
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        throw WorkerAssignmentException(
          message: 'Invalid worker assignment response',
        );
      }
    } on DioException catch (error) {
      if (error.type == DioExceptionType.connectionError) {
        throw const WorkerAssignmentException(
          message: 'Manager is offline. Cannot assign worker without session stickiness.',
        );
      }
      
      if (error.response?.statusCode == 401) {
        throw const InvalidApiKeyException();
      } else if (error.response?.statusCode == 403) {
        throw const AuthenticationException();
      } else {
        throw WorkerAssignmentException(
          message: 'Worker assignment failed: ${error.message}',
          cause: error,
        );
      }
    }
  }

  /// Connects to the worker over genuine Socket.IO (Engine.IO v4).
  Future<void> _connectWebSocket() async {
    if (_workerUrl == null) {
      throw const WorkerAssignmentException(message: 'No worker URL available');
    }

    try {
      // Engine.IO v4 endpoint. Normalise the scheme to ws/wss.
      var base = _workerUrl!;
      if (base.startsWith('https')) {
        base = 'wss${base.substring(5)}';
      } else if (base.startsWith('http')) {
        base = 'ws${base.substring(4)}';
      }
      final wsUrl = '$base/socket.io/?EIO=4&transport=websocket';

      _socketConnected = Completer<void>();
      _webSocket = WebSocketChannel.connect(Uri.parse(wsUrl));

      // Listen for Engine.IO frames.
      _webSocket!.stream.listen(
        _onEngineFrame,
        onError: _onWebSocketError,
        onDone: _onWebSocketClosed,
      );

      // Block until the Socket.IO CONNECT ack arrives (auth accepted).
      await _socketConnected!.future.timeout(
        config.timeout,
        onTimeout: () => throw const ConnectionException(
          message: 'Socket.IO handshake timed out',
        ),
      );
    } catch (error) {
      throw ConnectionException(
        message: 'WebSocket connection failed: $error',
        cause: error,
      );
    }
  }

  /// Handles a raw Engine.IO frame. Frame types: 0=OPEN, 2=PING, 3=PONG,
  /// 4=MESSAGE (carries a Socket.IO packet).
  void _onEngineFrame(dynamic raw) {
    final frame = raw is String ? raw : raw.toString();
    if (frame.isEmpty) return;

    final type = frame[0];
    final rest = frame.substring(1);

    switch (type) {
      case '0': // Engine.IO OPEN -> send Socket.IO CONNECT with auth payload.
        _webSocket!.sink.add(
          '40${jsonEncode({'apiKey': config.apiKey, 'userId': config.userId})}',
        );
        break;
      case '2': // Engine.IO PING -> PONG.
        _webSocket!.sink.add('3');
        break;
      case '3': // Engine.IO PONG - no action.
        break;
      case '4': // Engine.IO MESSAGE -> Socket.IO packet.
        _onSocketIoPacket(rest);
        break;
      default:
        break;
    }
  }

  /// Handles a Socket.IO packet. Packet types: 0=CONNECT, 1=DISCONNECT,
  /// 2=EVENT, 4=CONNECT_ERROR.
  void _onSocketIoPacket(String packet) {
    if (packet.isEmpty) return;

    final type = packet[0];
    final body = packet.substring(1);

    switch (type) {
      case '0': // CONNECT ack (auth accepted) - handshake complete.
        if (_socketConnected != null && !_socketConnected!.isCompleted) {
          _socketConnected!.complete();
        }
        break;
      case '2': // EVENT.
        _dispatchSocketIoEvent(body);
        break;
      case '4': // CONNECT_ERROR.
        if (_socketConnected != null && !_socketConnected!.isCompleted) {
          _socketConnected!.completeError(
            ConnectionException(message: 'Socket.IO connect error: $body'),
          );
        }
        break;
      default:
        break;
    }
  }

  /// Parses a Socket.IO EVENT body ["event", payload] and dispatches it.
  void _dispatchSocketIoEvent(String body) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! List || decoded.isEmpty) return;

      final event = decoded[0] as String;
      final payload = decoded.length > 1 ? decoded[1] : null;
      _handleServerEvent(
        event,
        payload is Map ? Map<String, dynamic>.from(payload) : <String, dynamic>{},
      );
    } catch (error) {
      _logger.e('Failed to parse Socket.IO event', error: error);
    }
  }

  /// Routes a decoded server event to either a pending request or a live push.
  void _handleServerEvent(String event, Map<String, dynamic> payload) {
    final channelName = payload['channel'] as String?;

    // Fan out to raw event listeners first. This carries the Slack-like
    // enhanced broadcasts (reaction_added, user_typing, thread_reply, ...) and
    // the request/response events the enhanced helpers await via once().
    _dispatchListeners(event, payload);

    switch (event) {
      case 'message':
        _handleIncomingMessage(_adaptMessage(payload));
        return;
      case 'error':
        // Worker errors don't carry a channel; fail the oldest pending request.
        final pending = _takeAnyPending();
        final reason = (payload['message'] ?? payload['type'] ?? 'Unknown error')
            .toString();
        if (pending != null) {
          pending.completeError(MessageDeliveryException(message: reason));
        } else {
          _handleError(payload);
        }
        return;
    }

    // The worker emits 'history' both as the explicit get_history RESPONSE
    // (query:true) and as a fire-and-forget on-join snapshot (~10 msgs, no query
    // flag). Only the query:true response may complete a pending getHistory
    // waiter; ignore the snapshot here so it can't resolve getHistory with the
    // wrong data. BUG-2026-0727-0012.
    if (event == 'history' && payload['query'] != true) {
      return;
    }

    // Response events correlate on "responseEvent:channel".
    final key = '$event:${channelName ?? ''}';
    final completer = _pending.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(_adaptResponse(event, payload));
    } else if (event == 'presence') {
      // Unsolicited presence push.
      _handlePresenceUpdate(_adaptPresence(payload));
    }
  }

  /// Removes and returns any single pending request (used for channel-less errors).
  Completer<Map<String, dynamic>>? _takeAnyPending() {
    if (_pending.isEmpty) return null;
    final key = _pending.keys.first;
    return _pending.remove(key);
  }

  /// Adapts a worker response event to the {success, ...} shape the channel expects.
  Map<String, dynamic> _adaptResponse(String event, Map<String, dynamic> p) {
    switch (event) {
      case 'subscribed':
      case 'unsubscribed':
        return {'success': true};
      case 'published':
        return {
          'success': true,
          'messageId': p['messageId'],
          'timestamp': p['timestamp'],
        };
      case 'presence':
        return {'success': true, 'presence': _adaptPresence(p)};
      case 'history':
        final messages = (p['messages'] as List? ?? [])
            .map((m) => _adaptMessage(Map<String, dynamic>.from(m as Map)))
            .toList();
        return {'success': true, 'messages': messages};
      default:
        return {'success': true, ...p};
    }
  }

  /// Adapts the worker presence payload {channel, occupancy, occupants} to the
  /// PresenceInfo JSON shape {channel, users, count, timestamp}.
  Map<String, dynamic> _adaptPresence(Map<String, dynamic> p) {
    final occupants = (p['occupants'] as List? ?? []);
    final users = occupants.map((o) {
      if (o is Map && o['userId'] != null) return o['userId'].toString();
      return o.toString();
    }).toList();
    return {
      'channel': p['channel'],
      'users': users,
      'count': p['occupancy'] ?? users.length,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Adapts the worker message envelope to the Message JSON shape.
  Map<String, dynamic> _adaptMessage(Map<String, dynamic> p) {
    final publisher = p['publisher'];
    final userId = publisher is Map ? publisher['userId']?.toString() : null;

    final ts = p['timestamp'];
    final String timestamp;
    if (ts is int) {
      timestamp = DateTime.fromMillisecondsSinceEpoch(ts).toIso8601String();
    } else if (ts is String) {
      timestamp = ts;
    } else {
      timestamp = DateTime.now().toIso8601String();
    }

    return {
      'id': p['id'] ?? OddSocketsUtils.generateMessageId(),
      'channel': p['channel'],
      'data': p['message'],
      'timestamp': timestamp,
      'userId': userId,
      'metadata':
          p['metadata'] is Map ? Map<String, dynamic>.from(p['metadata']) : null,
    };
  }

  /// Handles incoming messages.
  void _handleIncomingMessage(Map<String, dynamic> data) {
    try {
      final message = Message.fromJson(data);
      _messageSubject.add(message);

      // Forward to specific channel if it exists
      final channel = _channels[message.channel];
      channel?._handleMessage(message);
    } catch (error) {
      _logger.e('Failed to handle incoming message', error: error);
    }
  }

  /// Handles presence updates.
  void _handlePresenceUpdate(Map<String, dynamic> data) {
    try {
      final presenceInfo = PresenceInfo.fromJson(data);
      
      // Forward to specific channel if it exists
      final channel = _channels[presenceInfo.channel];
      channel?._handlePresence(presenceInfo);

      // Emit presence event
      _eventSubject.add({
        'type': EventType.presence.name,
        'presence': presenceInfo.toJson(),
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      _logger.e('Failed to handle presence update', error: error);
    }
  }

  /// Handles error messages.
  void _handleError(Map<String, dynamic> data) {
    final errorCode = data['code'] as String? ?? 'UNKNOWN_ERROR';
    final errorMessage = data['message'] as String? ?? 'Unknown error occurred';
    
    final exception = ExceptionFactory.fromError(
      code: errorCode,
      message: errorMessage,
      details: data,
    );

    _logger.e('Received error: $exception');

    // Emit error event
    _eventSubject.add({
      'type': EventType.error.name,
      'error': exception.toString(),
      'code': errorCode,
      'timestamp': DateTime.now().toIso8601String(),
    });

    // Handle reconnection if needed
    if (exception.shouldReconnect && _shouldReconnect()) {
      _scheduleReconnect();
    }
  }

  /// Handles WebSocket errors.
  void _onWebSocketError(error) {
    _logger.e('WebSocket error', error: error);
    
    final exception = WebSocketException(
      message: 'WebSocket error: $error',
      cause: error,
    );

    _updateConnectionState(ConnectionState.failed);

    // Emit error event
    _eventSubject.add({
      'type': EventType.error.name,
      'error': exception.toString(),
      'timestamp': DateTime.now().toIso8601String(),
    });

    if (_shouldReconnect()) {
      _scheduleReconnect();
    }
  }

  /// Handles WebSocket closure.
  void _onWebSocketClosed() {
    _logger.i('WebSocket connection closed');
    
    if (connectionState != ConnectionState.disconnected) {
      _updateConnectionState(ConnectionState.disconnected);
      
      // Emit disconnected event
      _eventSubject.add({
        'type': EventType.disconnected.name,
        'timestamp': DateTime.now().toIso8601String(),
      });

      if (_shouldReconnect()) {
        _scheduleReconnect();
      }
    }
  }

  /// Heartbeat is server-driven under Engine.IO: the worker sends PING ('2')
  /// and we reply PONG ('3') in [_onEngineFrame]. No client-side timer needed.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
  }

  /// Handles connectivity changes.
  void _onConnectivityChanged(ConnectivityResult result) {
    if (result == ConnectivityResult.none) {
      _logger.w('Network connectivity lost');
      if (isConnected) {
        _updateConnectionState(ConnectionState.disconnected);
      }
    } else if (isDisconnected && config.autoConnect) {
      _logger.i('Network connectivity restored, attempting to reconnect');
      _scheduleReconnect();
    }
  }

  /// Determines if reconnection should be attempted.
  bool _shouldReconnect() {
    return !_disposed && 
           _reconnectAttempts < config.reconnectAttempts &&
           config.autoConnect;
  }

  /// Schedules a reconnection attempt.
  void _scheduleReconnect() {
    if (_reconnectTimer?.isActive == true) {
      return; // Already scheduled
    }

    _reconnectAttempts++;
    _updateConnectionState(ConnectionState.reconnecting);

    // Exponential backoff with jitter
    final delay = Duration(
      milliseconds: (1000 * (1 << (_reconnectAttempts - 1).clamp(0, 5))).toInt() +
                   (DateTime.now().millisecondsSinceEpoch % 1000),
    );

    _logger.i('Scheduling reconnection attempt $_reconnectAttempts in ${delay.inSeconds}s');

    _reconnectTimer = Timer(delay, () async {
      if (_disposed) return;

      try {
        await connect();
        
        // Emit reconnected event
        _eventSubject.add({
          'type': EventType.reconnected.name,
          'attempts': _reconnectAttempts,
          'timestamp': DateTime.now().toIso8601String(),
        });
      } catch (error) {
        _logger.e('Reconnection attempt $_reconnectAttempts failed', error: error);
        
        if (_reconnectAttempts >= config.reconnectAttempts) {
          _logger.e('Maximum reconnection attempts reached');
          
          final exception = MaxReconnectAttemptsException(attempts: _reconnectAttempts);
          
          // Emit max attempts reached event
          _eventSubject.add({
            'type': EventType.maxReconnectAttemptsReached.name,
            'attempts': _reconnectAttempts,
            'error': exception.toString(),
            'timestamp': DateTime.now().toIso8601String(),
          });
        } else if (_shouldReconnect()) {
          _scheduleReconnect();
        }
      }
    });
  }

  /// Updates the connection state and notifies listeners.
  void _updateConnectionState(ConnectionState newState) {
    if (_connectionStateSubject.value != newState) {
      _connectionStateSubject.add(newState);
      _logger.d('Connection state changed to: $newState');
    }
  }

  /// Get assigned worker information
  Map<String, dynamic>? getWorkerInfo() {
    if (_workerId == null || _workerUrl == null) {
      return null;
    }
    
    return {
      'workerId': _workerId,
      'workerUrl': _workerUrl,
    };
  }
  
  /// Get client identifier used for session stickiness
  String getClientIdentifier() {
    return _clientIdentifier;
  }
  
  /// Get session information
  Map<String, dynamic>? getSessionInfo() {
    return _sessionInfo;
  }

  /// Internal: Generate consistent client identifier for session stickiness
  String _generateClientIdentifier() {
    // Create a consistent identifier based on API key and user ID
    final baseId = config.userId ?? 'default';
    final apiKeyHash = _hashString(config.apiKey);
    return '${apiKeyHash}_$baseId';
  }
  
  /// Internal: Simple hash function for API key
  int _hashString(String str) {
    int hash = 0;
    if (str.isEmpty) return hash;
    for (int i = 0; i < str.length; i++) {
      final char = str.codeUnitAt(i);
      hash = ((hash << 5) - hash) + char;
      hash = hash & 0xFFFFFFFF; // Convert to 32-bit integer
    }
    return hash.abs();
  }

  /// Disposes of the client and releases resources.
  Future<void> dispose() async {
    if (_disposed) return;
    
    _disposed = true;
    _logger.i('Disposing OddSockets client');

    // Disconnect if connected
    if (!isDisconnected) {
      await disconnect();
    }

    // Cancel subscriptions and timers. Cancelling the connectivity stream can
    // touch the platform channel, which is absent in headless runtimes; guard it.
    try {
      await _connectivitySubscription?.cancel();
    } catch (_) {
      // Connectivity teardown unavailable - ignore.
    }
    _connectivitySubscription = null;
    _reconnectTimer?.cancel();
    _heartbeatTimer?.cancel();

    // Close streams
    await _connectionStateSubject.close();
    await _messageSubject.close();
    await _eventSubject.close();

    // Dispose channels
    for (final channel in _channels.values) {
      await channel._dispose();
    }
    _channels.clear();

    // Close HTTP client
    _dio.close();

    _logger.i('OddSockets client disposed');
  }
}
