import 'package:meta/meta.dart';

/// Base exception class for all OddSockets-related errors.
///
/// This class provides a structured way to handle errors that occur
/// during OddSockets operations, with specific error codes and recovery suggestions.
@immutable
abstract class OddSocketsException implements Exception {
  /// The error code identifying the type of error
  final String code;

  /// Human-readable error message
  final String message;

  /// Optional underlying cause of the error
  final Object? cause;

  /// Optional stack trace from the underlying error
  final StackTrace? stackTrace;

  /// Creates a new OddSockets exception.
  const OddSocketsException({
    required this.code,
    required this.message,
    this.cause,
    this.stackTrace,
  });

  /// Gets a user-friendly description of the error
  String get description => message;

  /// Gets suggestions for recovering from this error
  List<String> get recoverySuggestions => [];

  /// Whether this error is recoverable
  bool get isRecoverable => false;

  /// Whether this error should trigger a reconnection attempt
  bool get shouldReconnect => false;

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (cause != null) {
      buffer.write(' (caused by: $cause)');
    }
    return buffer.toString();
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OddSocketsException &&
        other.code == code &&
        other.message == message &&
        other.cause == cause;
  }

  @override
  int get hashCode => Object.hash(code, message, cause);
}

/// Exception thrown when the API key is invalid or missing.
class InvalidApiKeyException extends OddSocketsException {
  const InvalidApiKeyException({
    String message = 'Invalid or missing API key',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'INVALID_API_KEY',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Verify your API key is correct',
        'Check that your API key starts with "ak_"',
        'Ensure your API key has not expired',
        'Contact support if the issue persists',
      ];
}

/// Exception thrown when connection to OddSockets fails.
class ConnectionException extends OddSocketsException {
  const ConnectionException({
    String message = 'Failed to connect to OddSockets',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'CONNECTION_FAILED',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  bool get isRecoverable => true;

  @override
  bool get shouldReconnect => true;

  @override
  List<String> get recoverySuggestions => [
        'Check your internet connection',
        'Verify the manager URL is correct',
        'Try again in a few moments',
        'Check if OddSockets service is operational',
      ];
}

/// Exception thrown when authentication fails.
class AuthenticationException extends OddSocketsException {
  const AuthenticationException({
    String message = 'Authentication failed',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'AUTHENTICATION_FAILED',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Verify your API key is valid',
        'Check your account status',
        'Ensure your subscription is active',
        'Contact support for assistance',
      ];
}

/// Exception thrown when access to a channel is denied.
class ChannelAccessDeniedException extends OddSocketsException {
  /// The channel that access was denied to
  final String channel;

  const ChannelAccessDeniedException({
    required this.channel,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'CHANNEL_ACCESS_DENIED',
          message: message ?? 'Access denied to channel: $channel',
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Check channel permissions in your dashboard',
        'Verify the channel name is correct',
        'Ensure your API key has access to this channel',
        'Contact your administrator for access',
      ];
}

/// Exception thrown when message delivery fails.
class MessageDeliveryException extends OddSocketsException {
  /// The message that failed to deliver
  final String? messageId;

  /// The channel the message was being sent to
  final String? channel;

  const MessageDeliveryException({
    this.messageId,
    this.channel,
    String message = 'Failed to deliver message',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'MESSAGE_DELIVERY_FAILED',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  bool get isRecoverable => true;

  @override
  List<String> get recoverySuggestions => [
        'Check your connection status',
        'Verify the channel exists and is accessible',
        'Try resending the message',
        'Check message size limits',
      ];
}

/// Exception thrown when configuration is invalid.
class InvalidConfigurationException extends OddSocketsException {
  const InvalidConfigurationException({
    String message = 'Invalid configuration',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'INVALID_CONFIGURATION',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Review your configuration parameters',
        'Check the documentation for valid values',
        'Ensure all required fields are provided',
        'Validate URL formats and timeouts',
      ];
}

/// Exception thrown when worker assignment fails.
class WorkerAssignmentException extends OddSocketsException {
  const WorkerAssignmentException({
    String message = 'Failed to assign worker',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'WORKER_ASSIGNMENT_FAILED',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  bool get isRecoverable => true;

  @override
  bool get shouldReconnect => true;

  @override
  List<String> get recoverySuggestions => [
        'Wait a moment and try reconnecting',
        'Check OddSockets service status',
        'Verify your subscription limits',
        'Contact support if the issue persists',
      ];
}

/// Exception thrown when maximum reconnection attempts are reached.
class MaxReconnectAttemptsException extends OddSocketsException {
  /// Number of attempts that were made
  final int attempts;

  const MaxReconnectAttemptsException({
    required this.attempts,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'MAX_RECONNECT_ATTEMPTS_REACHED',
          message: message ?? 'Maximum reconnection attempts ($attempts) reached',
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Check your internet connection',
        'Verify OddSockets service is operational',
        'Try connecting again later',
        'Consider increasing reconnection attempts in configuration',
      ];
}

/// Exception thrown when an operation times out.
class OperationTimeoutException extends OddSocketsException {
  /// The operation that timed out
  final String operation;

  /// The timeout duration that was exceeded
  final Duration timeout;

  OperationTimeoutException({
    required this.operation,
    required this.timeout,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'OPERATION_TIMEOUT',
          message: message ?? 'Operation "$operation" timed out after ${timeout.inSeconds}s',
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  bool get isRecoverable => true;

  @override
  List<String> get recoverySuggestions => [
        'Check your internet connection speed',
        'Try increasing the timeout in configuration',
        'Retry the operation',
        'Check if the service is experiencing high load',
      ];
}

/// Exception thrown when a channel name is invalid.
class InvalidChannelNameException extends OddSocketsException {
  /// The invalid channel name
  final String channelName;

  const InvalidChannelNameException({
    required this.channelName,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'INVALID_CHANNEL_NAME',
          message: message ?? 'Invalid channel name: "$channelName"',
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Channel names must be non-empty strings',
        'Avoid special characters in channel names',
        'Use alphanumeric characters, hyphens, and underscores',
        'Check the documentation for naming conventions',
      ];
}

/// Exception thrown when a message exceeds size limits.
class MessageSizeException extends OddSocketsException {
  /// The actual size of the message in bytes
  final int actualSize;

  /// The maximum allowed size in bytes
  final int maxSize;

  const MessageSizeException({
    required this.actualSize,
    required this.maxSize,
    String? message,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'MESSAGE_SIZE_EXCEEDED',
          message: message ?? 'Message size ($actualSize bytes) exceeds maximum allowed size ($maxSize bytes)',
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Reduce the message size to under ${(maxSize / 1024).round()}KB',
        'Split large messages into smaller chunks',
        'Consider using message compression',
        'Remove unnecessary data from the message',
      ];
}

/// Exception thrown when a WebSocket error occurs.
class WebSocketException extends OddSocketsException {
  /// The WebSocket close code, if available
  final int? closeCode;

  /// The WebSocket close reason, if available
  final String? closeReason;

  const WebSocketException({
    this.closeCode,
    this.closeReason,
    String message = 'WebSocket error occurred',
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: 'WEBSOCKET_ERROR',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  bool get isRecoverable => closeCode != 1002 && closeCode != 1003; // Not protocol or data errors

  @override
  bool get shouldReconnect => isRecoverable;

  @override
  List<String> get recoverySuggestions => [
        if (closeCode == 1006) 'Connection was closed abnormally - check network',
        if (closeCode == 1011) 'Server error - try again later',
        if (closeCode == 1012) 'Service is restarting - wait and reconnect',
        'Check your internet connection',
        'Verify the WebSocket endpoint is accessible',
        'Try reconnecting in a few moments',
      ];
}

/// Utility class for creating exceptions from error responses.
class ExceptionFactory {
  /// Creates an appropriate exception from an error code and message.
  static OddSocketsException fromError({
    required String code,
    required String message,
    Object? cause,
    StackTrace? stackTrace,
    Map<String, dynamic>? details,
  }) {
    switch (code) {
      case 'INVALID_API_KEY':
        return InvalidApiKeyException(
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'CONNECTION_FAILED':
        return ConnectionException(
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'AUTHENTICATION_FAILED':
        return AuthenticationException(
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'CHANNEL_ACCESS_DENIED':
        return ChannelAccessDeniedException(
          channel: details?['channel'] ?? 'unknown',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'MESSAGE_DELIVERY_FAILED':
        return MessageDeliveryException(
          messageId: details?['messageId'],
          channel: details?['channel'],
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'INVALID_CONFIGURATION':
        return InvalidConfigurationException(
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'WORKER_ASSIGNMENT_FAILED':
        return WorkerAssignmentException(
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'MAX_RECONNECT_ATTEMPTS_REACHED':
        return MaxReconnectAttemptsException(
          attempts: details?['attempts'] ?? 0,
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'OPERATION_TIMEOUT':
        return OperationTimeoutException(
          operation: details?['operation'] ?? 'unknown',
          timeout: Duration(seconds: details?['timeout'] ?? 0),
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'INVALID_CHANNEL_NAME':
        return InvalidChannelNameException(
          channelName: details?['channelName'] ?? 'unknown',
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'MESSAGE_SIZE_EXCEEDED':
        return MessageSizeException(
          actualSize: details?['actualSize'] ?? 0,
          maxSize: details?['maxSize'] ?? 0,
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      case 'WEBSOCKET_ERROR':
        return WebSocketException(
          closeCode: details?['closeCode'],
          closeReason: details?['closeReason'],
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
      default:
        return _GenericOddSocketsException(
          code: code,
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );
    }
  }
}

/// Generic exception for unknown error codes.
class _GenericOddSocketsException extends OddSocketsException {
  const _GenericOddSocketsException({
    required String code,
    required String message,
    Object? cause,
    StackTrace? stackTrace,
  }) : super(
          code: code,
          message: message,
          cause: cause,
          stackTrace: stackTrace,
        );

  @override
  List<String> get recoverySuggestions => [
        'Check the error message for specific details',
        'Verify your configuration and API key',
        'Try the operation again',
        'Contact support if the issue persists',
      ];
}
