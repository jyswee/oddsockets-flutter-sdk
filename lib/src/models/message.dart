import 'package:json_annotation/json_annotation.dart';
import 'package:meta/meta.dart';

part 'message.g.dart';

/// Represents a message received from OddSockets.
///
/// This class encapsulates all information about a message including its content,
/// metadata, and routing information.
@immutable
@JsonSerializable()
class Message {
  /// Unique identifier for the message
  final String id;

  /// The channel this message was sent to
  final String channel;

  /// The message data (can be any JSON-serializable type)
  final dynamic data;

  /// When the message was created
  final DateTime timestamp;

  /// Optional user ID of the sender
  final String? userId;

  /// Optional metadata associated with the message
  final Map<String, dynamic>? metadata;

  /// Creates a new message instance.
  const Message({
    required this.id,
    required this.channel,
    this.data,
    required this.timestamp,
    this.userId,
    this.metadata,
  });

  /// Creates a message from JSON data.
  factory Message.fromJson(Map<String, dynamic> json) => _$MessageFromJson(json);

  /// Converts this message to JSON.
  Map<String, dynamic> toJson() => _$MessageToJson(this);

  /// Creates a new message with generated ID.
  factory Message.create({
    required String channel,
    dynamic data,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: _generateMessageId(),
      channel: channel,
      data: data,
      timestamp: DateTime.now(),
      userId: userId,
      metadata: metadata,
    );
  }

  /// Gets a metadata value by key.
  T? getMetadataValue<T>(String key) {
    return metadata?[key] as T?;
  }

  /// Checks if this message has metadata.
  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;

  /// Checks if this message has data.
  bool get hasData => data != null;

  /// Creates a copy of this message with the given fields replaced.
  Message copyWith({
    String? id,
    String? channel,
    dynamic data,
    DateTime? timestamp,
    String? userId,
    Map<String, dynamic>? metadata,
  }) {
    return Message(
      id: id ?? this.id,
      channel: channel ?? this.channel,
      data: data ?? this.data,
      timestamp: timestamp ?? this.timestamp,
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Message &&
        other.id == id &&
        other.channel == channel &&
        other.data == data &&
        other.timestamp == timestamp &&
        other.userId == userId &&
        _mapEquals(other.metadata, metadata);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      channel,
      data,
      timestamp,
      userId,
      metadata,
    );
  }

  @override
  String toString() {
    return 'Message('
        'id: $id, '
        'channel: $channel, '
        'data: $data, '
        'timestamp: $timestamp, '
        'userId: $userId, '
        'metadata: $metadata'
        ')';
  }

  static String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}_${_randomString(8)}';
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    return List.generate(length, (index) => chars[(random + index) % chars.length]).join();
  }

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
