import 'package:meta/meta.dart';

import '../services/manager_discovery.dart';

/// Configuration class for OddSockets client.
///
/// This class holds all configuration parameters needed to connect to OddSockets.
/// Use [OddSocketsConfigBuilder] for a fluent configuration experience.
@immutable
class OddSocketsConfig {
  /// The API key for authentication
  final String apiKey;

  /// The manager URL for worker assignment.
  ///
  /// Null means "not configured": [ManagerDiscovery] then falls back to the
  /// environment and finally to the public endpoint. Keeping null distinct from
  /// a value stops a deliberate choice being confused with a default.
  final String? managerUrl;

  /// Optional user ID for the client
  final String? userId;

  /// Whether to automatically connect on client creation
  final bool autoConnect;

  /// Number of reconnection attempts before giving up
  final int reconnectAttempts;

  /// Heartbeat interval in seconds
  final Duration heartbeatInterval;

  /// Request timeout duration
  final Duration timeout;

  /// Creates a new configuration instance.
  const OddSocketsConfig({
    required this.apiKey,
    this.managerUrl,
    this.userId,
    this.autoConnect = true,
    this.reconnectAttempts = 5,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.timeout = const Duration(seconds: 10),
  });

  /// Creates a configuration with just an API key using default values.
  factory OddSocketsConfig.defaultConfig(String apiKey) {
    return OddSocketsConfig(apiKey: apiKey);
  }

  /// Creates a builder with an API key pre-set.
  static OddSocketsConfigBuilder builder(String apiKey) {
    return OddSocketsConfigBuilder()..apiKey(apiKey);
  }

  /// Validates the configuration.
  ///
  /// Throws [ArgumentError] if configuration is invalid.
  void validate() {
    if (apiKey.isEmpty) {
      throw ArgumentError('API key is required');
    }

    if (!apiKey.startsWith('ak_')) {
      throw ArgumentError('Invalid API key format');
    }

    final configuredManagerUrl = managerUrl;
    if (configuredManagerUrl != null) {
      ManagerDiscovery.normalizeManagerUrl(configuredManagerUrl);
    }

    if (reconnectAttempts < 0) {
      throw ArgumentError('Reconnect attempts must be non-negative');
    }

    if (heartbeatInterval.inSeconds <= 0) {
      throw ArgumentError('Heartbeat interval must be positive');
    }

    if (timeout.inSeconds <= 0) {
      throw ArgumentError('Timeout must be positive');
    }
  }

  /// Returns a map representation of the configuration.
  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'managerUrl': managerUrl,
      'userId': userId,
      'autoConnect': autoConnect,
      'reconnectAttempts': reconnectAttempts,
      'heartbeatInterval': heartbeatInterval.inSeconds,
      'timeout': timeout.inSeconds,
    };
  }

  /// Creates a copy of this configuration with the given fields replaced.
  OddSocketsConfig copyWith({
    String? apiKey,
    String? managerUrl,
    String? userId,
    bool? autoConnect,
    int? reconnectAttempts,
    Duration? heartbeatInterval,
    Duration? timeout,
  }) {
    return OddSocketsConfig(
      apiKey: apiKey ?? this.apiKey,
      managerUrl: managerUrl ?? this.managerUrl,
      userId: userId ?? this.userId,
      autoConnect: autoConnect ?? this.autoConnect,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
      heartbeatInterval: heartbeatInterval ?? this.heartbeatInterval,
      timeout: timeout ?? this.timeout,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OddSocketsConfig &&
        other.apiKey == apiKey &&
        other.managerUrl == managerUrl &&
        other.userId == userId &&
        other.autoConnect == autoConnect &&
        other.reconnectAttempts == reconnectAttempts &&
        other.heartbeatInterval == heartbeatInterval &&
        other.timeout == timeout;
  }

  @override
  int get hashCode {
    return Object.hash(
      apiKey,
      managerUrl,
      userId,
      autoConnect,
      reconnectAttempts,
      heartbeatInterval,
      timeout,
    );
  }

  @override
  String toString() {
    return 'OddSocketsConfig('
        'apiKey: ${apiKey.substring(0, 10)}..., '
        'managerUrl: $managerUrl, '
        'userId: $userId, '
        'autoConnect: $autoConnect, '
        'reconnectAttempts: $reconnectAttempts, '
        'heartbeatInterval: $heartbeatInterval, '
        'timeout: $timeout'
        ')';
  }
}

/// Builder class for creating [OddSocketsConfig] instances using a fluent interface.
///
/// This builder provides a Flutter-idiomatic way to construct configuration objects
/// with method chaining and sensible defaults.
class OddSocketsConfigBuilder {
  String _apiKey = '';
  String? _managerUrl;
  String? _userId;
  bool _autoConnect = true;
  int _reconnectAttempts = 5;
  Duration _heartbeatInterval = const Duration(seconds: 30);
  Duration _timeout = const Duration(seconds: 10);

  /// Sets the API key.
  OddSocketsConfigBuilder apiKey(String apiKey) {
    _apiKey = apiKey;
    return this;
  }

  /// Sets the manager URL. This value is used verbatim: no other endpoint is
  /// ever tried on its behalf.
  OddSocketsConfigBuilder managerUrl(String managerUrl) {
    _managerUrl = managerUrl;
    return this;
  }

  /// Sets the user ID.
  OddSocketsConfigBuilder userId(String userId) {
    _userId = userId;
    return this;
  }

  /// Sets whether to auto-connect.
  OddSocketsConfigBuilder autoConnect([bool autoConnect = true]) {
    _autoConnect = autoConnect;
    return this;
  }

  /// Sets the reconnect attempts.
  OddSocketsConfigBuilder reconnectAttempts(int attempts) {
    _reconnectAttempts = attempts;
    return this;
  }

  /// Sets the heartbeat interval.
  OddSocketsConfigBuilder heartbeatInterval(Duration interval) {
    _heartbeatInterval = interval;
    return this;
  }

  /// Sets the timeout duration.
  OddSocketsConfigBuilder timeout(Duration timeout) {
    _timeout = timeout;
    return this;
  }

  /// Sets common development configuration.
  OddSocketsConfigBuilder development() {
    _managerUrl = 'http://localhost:3001';
    _timeout = const Duration(seconds: 30);
    _heartbeatInterval = const Duration(seconds: 10);
    return this;
  }

  /// Sets common production configuration.
  OddSocketsConfigBuilder production() {
    _managerUrl = ManagerDiscovery.defaultManagerUrl;
    _timeout = const Duration(seconds: 10);
    _heartbeatInterval = const Duration(seconds: 30);
    return this;
  }

  /// Sets configuration optimized for mobile devices.
  OddSocketsConfigBuilder mobile() {
    _heartbeatInterval = const Duration(seconds: 45);
    _timeout = const Duration(seconds: 15);
    _reconnectAttempts = 10;
    return this;
  }

  /// Sets configuration optimized for web applications.
  OddSocketsConfigBuilder web() {
    _heartbeatInterval = const Duration(seconds: 20);
    _timeout = const Duration(seconds: 8);
    _reconnectAttempts = 3;
    return this;
  }

  /// Builds the configuration.
  ///
  /// Throws [ArgumentError] if configuration is invalid.
  OddSocketsConfig build() {
    final config = OddSocketsConfig(
      apiKey: _apiKey,
      managerUrl: _managerUrl,
      userId: _userId,
      autoConnect: _autoConnect,
      reconnectAttempts: _reconnectAttempts,
      heartbeatInterval: _heartbeatInterval,
      timeout: _timeout,
    );

    config.validate();
    return config;
  }
}
