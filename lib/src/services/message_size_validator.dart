import 'dart:convert';
import 'dart:typed_data';

import '../exceptions/oddsockets_exception.dart';

/// Message size limits (industry standard - matches PubNub)
class MessageSizeLimits {
  static const int maxMessageSize = 32768; // 32KB in bytes
  static const int maxMessageSizeKB = 32;
}

/// Validates message size against industry standards
class MessageSizeValidator {
  /// Validate message size
  /// 
  /// [message] Message to validate
  /// Throws [MessageSizeException] if message exceeds size limit
  /// Returns the message size in bytes
  static int validateMessageSize(dynamic message) {
    final String messageStr = message is String ? message : jsonEncode(message);
    final Uint8List messageBytes = Uint8List.fromList(utf8.encode(messageStr));
    final int messageSize = messageBytes.length;
    
    if (messageSize > MessageSizeLimits.maxMessageSize) {
      throw MessageSizeException(
        message: 'Message size (${(messageSize / 1024).round()}KB) exceeds maximum allowed size of ${MessageSizeLimits.maxMessageSizeKB}KB. '
                'This limit matches industry standards (PubNub, Socket.IO) for reliable real-time messaging.',
        actualSize: messageSize,
        maxSize: MessageSizeLimits.maxMessageSize,
      );
    }
    
    return messageSize;
  }
  
  /// Check if message size is valid without throwing
  /// 
  /// [message] Message to check
  /// Returns true if message is within size limits
  static bool isValidMessageSize(dynamic message) {
    try {
      validateMessageSize(message);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  /// Get message size in bytes
  /// 
  /// [message] Message to measure
  /// Returns the message size in bytes
  static int getMessageSize(dynamic message) {
    final String messageStr = message is String ? message : jsonEncode(message);
    final Uint8List messageBytes = Uint8List.fromList(utf8.encode(messageStr));
    return messageBytes.length;
  }
  
  /// Get message size in KB
  /// 
  /// [message] Message to measure
  /// Returns the message size in KB (rounded)
  static int getMessageSizeKB(dynamic message) {
    return (getMessageSize(message) / 1024).round();
  }
}
