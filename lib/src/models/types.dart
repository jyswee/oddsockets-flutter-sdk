import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';
import 'message.dart';

part 'types.g.dart';

/// Represents the connection state of the OddSockets client.
enum ConnectionState {
  @JsonValue('disconnected')
  disconnected,
  @JsonValue('connecting')
  connecting,
  @JsonValue('connected')
  connected,
  @JsonValue('reconnecting')
  reconnecting,
  @JsonValue('failed')
  failed;

  bool get isConnected => this == ConnectionState.connected;
  bool get isConnecting => this == ConnectionState.connecting || this == ConnectionState.reconnecting;
  bool get isDisconnected => this == ConnectionState.disconnected || this == ConnectionState.failed;

  @override
  String toString() => name.substring(0, 1).toUpperCase() + name.substring(1);
}

/// Represents different event types emitted by the OddSockets client.
enum EventType {
  @JsonValue('connected')
  connected,
  @JsonValue('disconnected')
  disconnected,
  @JsonValue('reconnected')
  reconnected,
  @JsonValue('error')
  error,
  @JsonValue('message')
  message,
  @JsonValue('presence')
  presence,
  @JsonValue('worker_assigned')
  workerAssigned,
  @JsonValue('max_reconnect_attempts_reached')
  maxReconnectAttemptsReached;

  bool get isConnectionEvent {
    switch (this) {
      case EventType.connected:
      case EventType.disconnected:
      case EventType.reconnected:
      case EventType.workerAssigned:
      case EventType.maxReconnectAttemptsReached:
        return true;
      default:
        return false;
    }
  }

  bool get isMessageEvent {
    switch (this) {
      case EventType.message:
      case EventType.presence:
        return true;
      default:
        return false;
    }
  }

  @override
  String toString() => name.replaceAll(RegExp(r'([A-Z])'), ' \$1').trim();
}

/// Represents presence information for a channel.
@immutable
@JsonSerializable()
class PresenceInfo {
  /// The channel name
  final String channel;

  /// List of user IDs currently present
  final List<String> users;

  /// Total count of users present
  final int count;

  /// When this presence info was created
  final DateTime timestamp;

  const PresenceInfo({
    required this.channel,
    required this.users,
    required this.count,
    required this.timestamp,
  });

  factory PresenceInfo.fromJson(Map<String, dynamic> json) => _$PresenceInfoFromJson(json);
  Map<String, dynamic> toJson() => _$PresenceInfoToJson(this);

  /// Checks if a specific user is present
  bool isUserPresent(String userId) => users.contains(userId);

  /// Checks if the channel is empty
  bool get isEmpty => count == 0 || users.isEmpty;

  /// Gets the presence ratio compared to a maximum capacity
  double getPresenceRatio(int maxCapacity) {
    if (maxCapacity <= 0) return 0.0;
    return count / maxCapacity;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PresenceInfo &&
        other.channel == channel &&
        _listEquals(other.users, users) &&
        other.count == count &&
        other.timestamp == timestamp;
  }

  @override
  int get hashCode => Object.hash(channel, users, count, timestamp);

  @override
  String toString() => 'PresenceInfo(channel: $channel, count: $count, users: $users)';

  static bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// Represents the result of a publish operation.
@immutable
@JsonSerializable()
class PublishResult {
  /// Unique identifier for the published message
  final String messageId;

  /// When the message was published
  final DateTime timestamp;

  /// The channel the message was published to
  final String channel;

  /// Whether the publish was successful
  final bool success;

  const PublishResult({
    required this.messageId,
    required this.timestamp,
    required this.channel,
    required this.success,
  });

  factory PublishResult.fromJson(Map<String, dynamic> json) => _$PublishResultFromJson(json);
  Map<String, dynamic> toJson() => _$PublishResultToJson(this);

  /// Whether the publish was successful
  bool get isSuccessful => success;

  /// Whether the publish failed
  bool get isFailed => !success;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublishResult &&
        other.messageId == messageId &&
        other.timestamp == timestamp &&
        other.channel == channel &&
        other.success == success;
  }

  @override
  int get hashCode => Object.hash(messageId, timestamp, channel, success);

  @override
  String toString() => 'PublishResult(messageId: $messageId, channel: $channel, success: $success)';
}

/// Represents a message for bulk publishing.
@immutable
@JsonSerializable()
class BulkMessage {
  /// The channel to publish to
  final String channel;

  /// The message data
  final dynamic message;

  /// Optional publish options
  final PublishOptions? options;

  const BulkMessage(
    this.channel,
    this.message, [
    this.options,
  ]);

  factory BulkMessage.fromJson(Map<String, dynamic> json) => _$BulkMessageFromJson(json);
  Map<String, dynamic> toJson() => _$BulkMessageToJson(this);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BulkMessage &&
        other.channel == channel &&
        other.message == message &&
        other.options == options;
  }

  @override
  int get hashCode => Object.hash(channel, message, options);

  @override
  String toString() => 'BulkMessage(channel: $channel, message: $message)';
}

/// Represents the result of a bulk publish operation.
@immutable
@JsonSerializable()
class BulkResult {
  /// Whether this individual result was successful
  final bool success;

  /// The publish result if successful
  final PublishResult? result;

  /// Error message if failed
  final String? error;

  const BulkResult({
    required this.success,
    this.result,
    this.error,
  });

  factory BulkResult.fromJson(Map<String, dynamic> json) => _$BulkResultFromJson(json);
  Map<String, dynamic> toJson() => _$BulkResultToJson(this);

  /// Whether this result was successful
  bool get isSuccessful => success;

  /// Whether this result failed
  bool get isFailed => !success;

  /// Gets the error message with a default fallback
  String getErrorMessage([String defaultMessage = 'Unknown error']) {
    return error ?? defaultMessage;
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is BulkResult &&
        other.success == success &&
        other.result == result &&
        other.error == error;
  }

  @override
  int get hashCode => Object.hash(success, result, error);

  @override
  String toString() => 'BulkResult(success: $success, error: $error)';
}

/// Options for channel subscription.
@immutable
@JsonSerializable()
class SubscribeOptions {
  /// Whether to enable presence tracking
  final bool enablePresence;

  /// Whether to retain message history
  final bool retainHistory;

  /// Optional filter expression for messages
  final String? filterExpression;

  const SubscribeOptions({
    this.enablePresence = false,
    this.retainHistory = false,
    this.filterExpression,
  });

  factory SubscribeOptions.fromJson(Map<String, dynamic> json) => _$SubscribeOptionsFromJson(json);
  Map<String, dynamic> toJson() => _$SubscribeOptionsToJson(this);

  /// Creates options with presence enabled
  factory SubscribeOptions.withPresence() => const SubscribeOptions(enablePresence: true);

  /// Creates options with history enabled
  factory SubscribeOptions.withHistory() => const SubscribeOptions(retainHistory: true);

  /// Creates options with both presence and history enabled
  factory SubscribeOptions.withPresenceAndHistory() => const SubscribeOptions(
        enablePresence: true,
        retainHistory: true,
      );

  /// Creates options optimized for chat channels
  factory SubscribeOptions.chatChannel() => const SubscribeOptions(
        enablePresence: true,
        retainHistory: true,
      );

  /// Creates options optimized for notification channels
  factory SubscribeOptions.notificationChannel() => const SubscribeOptions(
        enablePresence: false,
        retainHistory: false,
      );

  /// Creates options optimized for data channels
  factory SubscribeOptions.dataChannel() => const SubscribeOptions(
        enablePresence: false,
        retainHistory: true,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SubscribeOptions &&
        other.enablePresence == enablePresence &&
        other.retainHistory == retainHistory &&
        other.filterExpression == filterExpression;
  }

  @override
  int get hashCode => Object.hash(enablePresence, retainHistory, filterExpression);

  @override
  String toString() => 'SubscribeOptions(enablePresence: $enablePresence, retainHistory: $retainHistory)';
}

/// Options for message publishing.
@immutable
@JsonSerializable()
class PublishOptions {
  /// Time-to-live in seconds
  final int? ttl;

  /// Optional metadata to attach to the message
  final Map<String, dynamic>? metadata;

  /// Whether to store this message in history
  final bool storeInHistory;

  const PublishOptions({
    this.ttl,
    this.metadata,
    this.storeInHistory = false,
  });

  factory PublishOptions.fromJson(Map<String, dynamic> json) => _$PublishOptionsFromJson(json);
  Map<String, dynamic> toJson() => _$PublishOptionsToJson(this);

  /// Creates options with history storage enabled
  factory PublishOptions.withHistory() => const PublishOptions(storeInHistory: true);

  /// Creates options with a specific TTL
  factory PublishOptions.withTTL(int seconds) => PublishOptions(ttl: seconds);

  /// Creates options optimized for chat messages
  factory PublishOptions.chatMessage() => const PublishOptions(
        storeInHistory: true,
        metadata: {'type': 'chat'},
      );

  /// Creates options optimized for system messages
  factory PublishOptions.systemMessage() => const PublishOptions(
        storeInHistory: true,
        metadata: {'type': 'system', 'priority': 'high'},
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PublishOptions &&
        other.ttl == ttl &&
        _mapEquals(other.metadata, metadata) &&
        other.storeInHistory == storeInHistory;
  }

  @override
  int get hashCode => Object.hash(ttl, metadata, storeInHistory);

  @override
  String toString() => 'PublishOptions(ttl: $ttl, storeInHistory: $storeInHistory)';

  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

/// Options for retrieving message history.
@immutable
@JsonSerializable()
class HistoryOptions {
  /// Maximum number of messages to retrieve
  final int? limit;

  /// Start time for history retrieval
  final DateTime? start;

  /// End time for history retrieval
  final DateTime? end;

  /// Whether to return messages in reverse chronological order
  final bool reverse;

  const HistoryOptions({
    this.limit,
    this.start,
    this.end,
    this.reverse = false,
  });

  factory HistoryOptions.fromJson(Map<String, dynamic> json) => _$HistoryOptionsFromJson(json);
  Map<String, dynamic> toJson() => _$HistoryOptionsToJson(this);

  /// Creates options with a specific limit
  factory HistoryOptions.limit(int count) => HistoryOptions(limit: count);

  /// Creates options for recent messages
  factory HistoryOptions.recent(int count) => HistoryOptions(limit: count, reverse: true);

  /// Creates options for the last hour
  factory HistoryOptions.lastHour([int count = 100]) => HistoryOptions(
        limit: count,
        start: DateTime.now().subtract(const Duration(hours: 1)),
        reverse: true,
      );

  /// Creates options for the last day
  factory HistoryOptions.lastDay([int count = 1000]) => HistoryOptions(
        limit: count,
        start: DateTime.now().subtract(const Duration(days: 1)),
        reverse: true,
      );

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is HistoryOptions &&
        other.limit == limit &&
        other.start == start &&
        other.end == end &&
        other.reverse == reverse;
  }

  @override
  int get hashCode => Object.hash(limit, start, end, reverse);

  @override
  String toString() => 'HistoryOptions(limit: $limit, reverse: $reverse)';
}

/// Common message types for structured messaging.
class MessageTypes {
  /// Creates a chat message structure
  static Map<String, dynamic> chatMessage(
    String text,
    String username, [
    String messageType = 'chat',
  ]) {
    return {
      'text': text,
      'username': username,
      'messageType': messageType,
      'timestamp': DateTime.now().toIso8601String(),
    };
  }

  /// Creates a notification message structure
  static Map<String, dynamic> notificationMessage(
    String title,
    String body, {
    String category = 'general',
    String priority = 'normal',
    Map<String, dynamic>? data,
  }) {
    return {
      'title': title,
      'body': body,
      'category': category,
      'priority': priority,
      'timestamp': DateTime.now().toIso8601String(),
      if (data != null) 'data': data,
    };
  }

  /// Creates a system message structure
  static Map<String, dynamic> systemMessage(
    String event,
    String description, [
    Map<String, dynamic>? metadata,
  ]) {
    return {
      'event': event,
      'description': description,
      'timestamp': DateTime.now().toIso8601String(),
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Creates a data event message structure
  static Map<String, dynamic> dataEvent(
    String eventType,
    dynamic payload, [
    String? source,
  ]) {
    return {
      'eventType': eventType,
      'payload': payload,
      'timestamp': DateTime.now().toIso8601String(),
      if (source != null) 'source': source,
    };
  }
}

/// Constants used throughout the SDK.
class Constants {
  static const String sdkVersion = '0.1.0-beta.1';
  static const String sdkName = 'OddSockets-Flutter-SDK';
  static const String userAgent = '$sdkName/$sdkVersion';
  static const String defaultManagerUrl = 'https://manager1.oddsockets.tyga.network';
  static const Duration defaultTimeout = Duration(seconds: 10);
  static const Duration defaultHeartbeatInterval = Duration(seconds: 30);
  static const int defaultReconnectAttempts = 5;
  static const int maxMessageHistorySize = 100;
}

/// Utility functions for creating common data structures.
class OddSocketsUtils {
  /// Generates a unique message ID
  static String generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// Generates a unique user ID
  static String generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  /// Creates a bulk message
  static BulkMessage bulkMessage(
    String channel,
    dynamic message, [
    PublishOptions? options,
  ]) {
    return BulkMessage(channel, message, options);
  }

  /// Creates multiple bulk messages for the same channel
  static List<BulkMessage> bulkMessages(
    String channel,
    List<dynamic> messages, [
    PublishOptions? options,
  ]) {
    return messages.map((message) => BulkMessage(channel, message, options)).toList();
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => chars[(random + index) % chars.length]).join();
  }
}

/// Error codes used throughout the SDK.
class ErrorCodes {
  static const String invalidApiKey = 'INVALID_API_KEY';
  static const String connectionFailed = 'CONNECTION_FAILED';
  static const String authenticationFailed = 'AUTHENTICATION_FAILED';
  static const String channelAccessDenied = 'CHANNEL_ACCESS_DENIED';
  static const String messageDeliveryFailed = 'MESSAGE_DELIVERY_FAILED';
  static const String invalidConfiguration = 'INVALID_CONFIGURATION';
  static const String workerAssignmentFailed = 'WORKER_ASSIGNMENT_FAILED';
  static const String maxReconnectAttemptsReached = 'MAX_RECONNECT_ATTEMPTS_REACHED';
  static const String operationTimeout = 'OPERATION_TIMEOUT';
  static const String invalidChannelName = 'INVALID_CHANNEL_NAME';
}
