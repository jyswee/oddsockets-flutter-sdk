import 'dart:async';

import 'package:meta/meta.dart';

import '../services/manager_discovery.dart';

/// Callback that mints a short-lived realtime token for keyless auth.
///
/// May return either a raw JWT string or a map shaped like the `/v1/token`
/// mint response: `{token, expiresAt, exp, ...}`. It is invoked before every
/// (re)connect and again shortly before the current token expires.
typedef TokenProvider = FutureOr<Object> Function();

/// Configuration class for OddSockets client.
///
/// This class holds all configuration parameters needed to connect to OddSockets.
/// Use [OddSocketsConfigBuilder] for a fluent configuration experience.
@immutable
class OddSocketsConfig {
  /// The API key for authentication.
  ///
  /// Empty when a [tokenProvider] is used instead (keyless token auth).
  final String apiKey;

  /// Callback that mints a short-lived realtime token, used INSTEAD of an
  /// API key. When set, the client resolves a fresh token before every
  /// (re)connect and silently refreshes it before expiry.
  final TokenProvider? tokenProvider;

  /// How long before token expiry the silent refresh fires, in milliseconds.
  final int tokenRefreshLeadMs;

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
    this.apiKey = '',
    this.tokenProvider,
    this.tokenRefreshLeadMs = 120000,
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
    if (tokenProvider == null) {
      if (apiKey.isEmpty) {
        throw ArgumentError('Either an API key or a tokenProvider is required');
      }

      if (!apiKey.startsWith('ak_')) {
        throw ArgumentError('Invalid API key format');
      }
    }

    if (tokenRefreshLeadMs < 0) {
      throw ArgumentError('tokenRefreshLeadMs must be non-negative');
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
      'tokenProvider': tokenProvider != null,
      'tokenRefreshLeadMs': tokenRefreshLeadMs,
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
    TokenProvider? tokenProvider,
    int? tokenRefreshLeadMs,
    String? managerUrl,
    String? userId,
    bool? autoConnect,
    int? reconnectAttempts,
    Duration? heartbeatInterval,
    Duration? timeout,
  }) {
    return OddSocketsConfig(
      apiKey: apiKey ?? this.apiKey,
      tokenProvider: tokenProvider ?? this.tokenProvider,
      tokenRefreshLeadMs: tokenRefreshLeadMs ?? this.tokenRefreshLeadMs,
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
        other.tokenProvider == tokenProvider &&
        other.tokenRefreshLeadMs == tokenRefreshLeadMs &&
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
      tokenProvider,
      tokenRefreshLeadMs,
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
    final auth = tokenProvider != null
        ? 'tokenProvider'
        : '${apiKey.length > 10 ? apiKey.substring(0, 10) : apiKey}...';
    return 'OddSocketsConfig('
        'auth: $auth, '
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
  TokenProvider? _tokenProvider;
  int _tokenRefreshLeadMs = 120000;
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

  /// Sets a token provider for keyless minted-token auth (used INSTEAD of an
  /// API key). The callback may return a raw JWT string or a map shaped like
  /// the `/v1/token` mint response.
  OddSocketsConfigBuilder tokenProvider(TokenProvider provider) {
    _tokenProvider = provider;
    return this;
  }

  /// Sets how long before token expiry the silent refresh fires (ms).
  OddSocketsConfigBuilder tokenRefreshLeadMs(int leadMs) {
    _tokenRefreshLeadMs = leadMs;
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
      tokenProvider: _tokenProvider,
      tokenRefreshLeadMs: _tokenRefreshLeadMs,
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
