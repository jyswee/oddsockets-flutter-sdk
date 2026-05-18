import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import 'package:rxdart/rxdart.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../config/oddsockets_config.dart';
import '../models/message.dart';
import '../models/types.dart';
import '../exceptions/oddsockets_exception.dart';
import '../services/manager_discovery.dart';
import '../services/message_size_validator.dart';
import 'oddsockets_channel.dart';

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

  /// Creates a new OddSockets client.
  OddSocketsClient(this.config) {
    _initializeClient();
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

    // Monitor connectivity changes
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(_onConnectivityChanged);

    // Auto-connect if configured
    if (config.autoConnect) {
      connect();
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
      _logger.e('Connection failed', error, stackTrace);
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
  Future<List<BulkResult>> publishBulk(List<BulkMessage> messages) async {
    if (!isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    if (messages.isEmpty) {
      return [];
    }

    try {
      final payload = {
        'type': 'bulk_publish',
        'messages': messages.map((m) => m.toJson()).toList(),
        'timestamp': DateTime.now().toIso8601String(),
      };

      final response = await _sendMessage(payload);
      
      if (response['success'] == true && response['results'] is List) {
        return (response['results'] as List)
            .map((result) => BulkResult.fromJson(result as Map<String, dynamic>))
            .toList();
      } else {
        throw MessageDeliveryException(
          message: 'Bulk publish failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    } catch (error) {
      _logger.e('Bulk publish failed', error);
      
      // Return failed results for all messages
      return messages.map((message) => BulkResult(
        success: false,
        error: error.toString(),
      )).toList();
    }
  }

  /// Sends a message through the WebSocket connection.
  Future<Map<String, dynamic>> _sendMessage(Map<String, dynamic> message) async {
    if (_webSocket == null) {
      throw const ConnectionException(message: 'WebSocket not connected');
    }

    final completer = Completer<Map<String, dynamic>>();
    final messageId = OddSocketsUtils.generateMessageId();
    
    message['id'] = messageId;

    // Set up response handler (simplified for this implementation)
    Timer(config.timeout, () {
      if (!completer.isCompleted) {
        completer.completeError(OperationTimeoutException(
          operation: 'send_message',
          timeout: config.timeout,
        ));
      }
    });

    try {
      _webSocket!.sink.add(jsonEncode(message));
      
      // For this implementation, we'll simulate a successful response
      // In a real implementation, you'd wait for the actual response
      completer.complete({
        'success': true,
        'messageId': messageId,
        'timestamp': DateTime.now().toIso8601String(),
      });
    } catch (error) {
      if (!completer.isCompleted) {
        completer.completeError(error);
      }
    }

    return completer.future;
  }

  /// Assigns a worker for this client.
  Future<void> _assignWorker() async {
    try {
      // Discover the optimal manager URL automatically
      final managerUrl = await ManagerDiscovery.discoverManagerUrl(config.apiKey);
      
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
          'managerUrl': managerUrl, // Include discovered manager URL for debugging
          'timestamp': DateTime.now().toIso8601String(),
        });
      } else {
        throw WorkerAssignmentException(
          message: 'Invalid worker assignment response',
        );
      }
    } on DioException catch (error) {
      // If manager is offline, try fallback logic
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

  /// Connects to the WebSocket.
  Future<void> _connectWebSocket() async {
    if (_workerUrl == null) {
      throw const WorkerAssignmentException(message: 'No worker URL available');
    }

    try {
      final wsUrl = _workerUrl!.replaceFirst('http', 'ws') + '/ws';
      _webSocket = WebSocketChannel.connect(
        Uri.parse(wsUrl),
        protocols: ['oddsockets-v1'],
      );

      // Listen for messages
      _webSocket!.stream.listen(
        _onWebSocketMessage,
        onError: _onWebSocketError,
        onDone: _onWebSocketClosed,
      );

      // Send authentication
      _webSocket!.sink.add(jsonEncode({
        'type': 'auth',
        'apiKey': config.apiKey,
        'userId': config.userId,
      }));

    } catch (error) {
      throw ConnectionException(
        message: 'WebSocket connection failed: $error',
        cause: error,
      );
    }
  }

  /// Handles incoming WebSocket messages.
  void _onWebSocketMessage(dynamic data) {
    try {
      final message = jsonDecode(data as String) as Map<String, dynamic>;
      
      switch (message['type']) {
        case 'message':
          _handleIncomingMessage(message);
          break;
        case 'presence':
          _handlePresenceUpdate(message);
          break;
        case 'error':
          _handleError(message);
          break;
        case 'pong':
          // Heartbeat response - no action needed
          break;
        default:
          _logger.w('Unknown message type: ${message['type']}');
      }
    } catch (error) {
      _logger.e('Failed to process WebSocket message', error);
    }
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
      _logger.e('Failed to handle incoming message', error);
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
      _logger.e('Failed to handle presence update', error);
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
    _logger.e('WebSocket error', error);
    
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

  /// Starts the heartbeat timer.
  void _startHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
      if (isConnected && _webSocket != null) {
        _webSocket!.sink.add(jsonEncode({
          'type': 'ping',
          'timestamp': DateTime.now().toIso8601String(),
        }));
      }
    });
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
        _logger.e('Reconnection attempt $_reconnectAttempts failed', error);
        
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

    // Cancel subscriptions and timers
    _connectivitySubscription?.cancel();
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
