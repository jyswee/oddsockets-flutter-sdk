import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';

import '../models/message.dart';
import '../models/types.dart';
import '../exceptions/oddsockets_exception.dart';
import '../services/message_size_validator.dart';
import 'oddsockets_client.dart';

/// Represents a channel for publishing and subscribing to messages.
///
/// Channels provide a way to organize messages by topic and manage
/// subscriptions, presence, and message history.
class OddSocketsChannel {
  /// The name of this channel
  final String name;

  /// Reference to the parent client
  final OddSocketsClient _client;

  /// Stream of messages for this channel
  final PublishSubject<Message> _messageSubject = PublishSubject<Message>();

  /// Stream of presence updates for this channel
  final BehaviorSubject<PresenceInfo?> _presenceSubject = BehaviorSubject<PresenceInfo?>();

  /// Current subscription options
  SubscribeOptions? _subscribeOptions;

  /// Message handler callback
  MessageHandler? _messageHandler;

  /// Whether this channel is currently subscribed
  bool _isSubscribed = false;

  /// Whether this channel has been disposed
  bool _disposed = false;

  /// Message history cache
  final List<Message> _messageHistory = [];

  /// Creates a new channel instance.
  OddSocketsChannel(this.name, this._client);

  /// Whether this channel is currently subscribed
  bool get isSubscribed => _isSubscribed;

  /// Stream of messages for this channel
  Stream<Message> get messageStream => _messageSubject.stream;

  /// Stream of presence updates for this channel
  Stream<PresenceInfo?> get presenceStream => _presenceSubject.stream;

  /// Current presence information
  PresenceInfo? get currentPresence => _presenceSubject.valueOrNull;

  /// Cached message history
  List<Message> get messageHistory => List.unmodifiable(_messageHistory);

  /// Subscribes to this channel with the given handler and options.
  Future<void> subscribe(
    MessageHandler handler, [
    SubscribeOptions? options,
  ]) async {
    if (_disposed) {
      throw InvalidChannelNameException(
        channelName: name,
        message: 'Channel has been disposed',
      );
    }

    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Client is not connected');
    }

    if (_isSubscribed) {
      // Update handler and options if already subscribed
      _messageHandler = handler;
      _subscribeOptions = options;
      return;
    }

    try {
      _messageHandler = handler;
      _subscribeOptions = options ?? const SubscribeOptions();

      // Send subscription request
      final response = await _client._sendMessage({
        'type': 'subscribe',
        'channel': name,
        'options': _subscribeOptions!.toJson(),
      });

      if (response['success'] == true) {
        _isSubscribed = true;
        
        // Request presence if enabled
        if (_subscribeOptions!.enablePresence) {
          await _requestPresence();
        }

        // Request history if enabled
        if (_subscribeOptions!.retainHistory) {
          await _requestHistory();
        }

        _client._logger.i('Subscribed to channel: $name');
      } else {
        throw ChannelAccessDeniedException(
          channel: name,
          message: 'Subscription failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    } catch (error) {
      _client._logger.e('Failed to subscribe to channel: $name', error);
      rethrow;
    }
  }

  /// Unsubscribes from this channel.
  Future<void> unsubscribe() async {
    if (!_isSubscribed) {
      return;
    }

    try {
      // Send unsubscription request
      final response = await _client._sendMessage({
        'type': 'unsubscribe',
        'channel': name,
      });

      if (response['success'] == true) {
        _isSubscribed = false;
        _messageHandler = null;
        _subscribeOptions = null;
        
        // Clear presence
        _presenceSubject.add(null);
        
        _client._logger.i('Unsubscribed from channel: $name');
      } else {
        throw MessageDeliveryException(
          channel: name,
          message: 'Unsubscription failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    } catch (error) {
      _client._logger.e('Failed to unsubscribe from channel: $name', error);
      rethrow;
    }
  }

  /// Publishes a message to this channel.
  Future<PublishResult> publish(
    dynamic message, [
    PublishOptions? options,
  ]) async {
    if (_disposed) {
      throw InvalidChannelNameException(
        channelName: name,
        message: 'Channel has been disposed',
      );
    }

    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Client is not connected');
    }

    try {
      // Validate message size before sending
      MessageSizeValidator.validateMessageSize(message);
      
      final publishOptions = options ?? const PublishOptions();
      final messageId = OddSocketsUtils.generateMessageId();

      final response = await _client._sendMessage({
        'type': 'publish',
        'channel': name,
        'message': message,
        'messageId': messageId,
        'options': publishOptions.toJson(),
      });

      if (response['success'] == true) {
        final result = PublishResult(
          messageId: response['messageId'] ?? messageId,
          timestamp: DateTime.tryParse(response['timestamp'] ?? '') ?? DateTime.now(),
          channel: name,
          success: true,
        );

        _client._logger.d('Published message to channel: $name');
        return result;
      } else {
        throw MessageDeliveryException(
          messageId: messageId,
          channel: name,
          message: 'Publish failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    } catch (error) {
      _client._logger.e('Failed to publish to channel: $name', error);
      rethrow;
    }
  }

  /// Retrieves message history for this channel.
  Future<List<Message>> getHistory([HistoryOptions? options]) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Client is not connected');
    }

    try {
      final historyOptions = options ?? const HistoryOptions();

      final response = await _client._sendMessage({
        'type': 'get_history',
        'channel': name,
        'options': historyOptions.toJson(),
      });

      if (response['success'] == true && response['messages'] is List) {
        final messages = (response['messages'] as List)
            .map((messageData) => Message.fromJson(messageData as Map<String, dynamic>))
            .toList();

        _client._logger.d('Retrieved ${messages.length} messages from history for channel: $name');
        return messages;
      } else {
        throw MessageDeliveryException(
          channel: name,
          message: 'History retrieval failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    } catch (error) {
      _client._logger.e('Failed to get history for channel: $name', error);
      rethrow;
    }
  }

  /// Gets current presence information for this channel.
  Future<PresenceInfo> getPresence() async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Client is not connected');
    }

    try {
      final response = await _client._sendMessage({
        'type': 'get_presence',
        'channel': name,
      });

      if (response['success'] == true && response['presence'] != null) {
        final presence = PresenceInfo.fromJson(response['presence'] as Map<String, dynamic>);
        
        // Update cached presence
        _presenceSubject.add(presence);
        
        _client._logger.d('Retrieved presence for channel: $name (${presence.count} users)');
        return presence;
      } else {
        throw MessageDeliveryException(
          channel: name,
          message: 'Presence retrieval failed: ${response['error'] ?? 'Unknown error'}',
        );
      }
    } catch (error) {
      _client._logger.e('Failed to get presence for channel: $name', error);
      rethrow;
    }
  }

  /// Requests presence information from the server.
  Future<void> _requestPresence() async {
    try {
      await getPresence();
    } catch (error) {
      _client._logger.w('Failed to request presence for channel: $name', error);
      // Don't rethrow - presence is optional
    }
  }

  /// Requests message history from the server.
  Future<void> _requestHistory([HistoryOptions? options]) async {
    try {
      final messages = await getHistory(options);
      
      // Add to local cache
      _messageHistory.clear();
      _messageHistory.addAll(messages);
      
      // Limit cache size
      if (_messageHistory.length > Constants.maxMessageHistorySize) {
        _messageHistory.removeRange(0, _messageHistory.length - Constants.maxMessageHistorySize);
      }
    } catch (error) {
      _client._logger.w('Failed to request history for channel: $name', error);
      // Don't rethrow - history is optional
    }
  }

  /// Handles an incoming message for this channel.
  void _handleMessage(Message message) {
    if (_disposed) return;

    // Add to history cache if enabled
    if (_subscribeOptions?.retainHistory == true) {
      _messageHistory.add(message);
      
      // Limit cache size
      if (_messageHistory.length > Constants.maxMessageHistorySize) {
        _messageHistory.removeAt(0);
      }
    }

    // Apply filter if specified
    if (_subscribeOptions?.filterExpression != null) {
      // Simple filter implementation - in a real implementation,
      // you might use a more sophisticated expression evaluator
      final filter = _subscribeOptions!.filterExpression!.toLowerCase();
      final messageText = message.data.toString().toLowerCase();
      
      if (!messageText.contains(filter)) {
        return; // Skip filtered messages
      }
    }

    // Emit to stream
    _messageSubject.add(message);

    // Call handler if set
    _messageHandler?.call(message);
  }

  /// Handles a presence update for this channel.
  void _handlePresence(PresenceInfo presence) {
    if (_disposed) return;

    _presenceSubject.add(presence);
    _client._logger.d('Presence updated for channel: $name (${presence.count} users)');
  }

  /// Creates a copy of this channel with the same configuration.
  OddSocketsChannel _copy() {
    final copy = OddSocketsChannel(name, _client);
    copy._subscribeOptions = _subscribeOptions;
    copy._messageHandler = _messageHandler;
    copy._isSubscribed = _isSubscribed;
    return copy;
  }

  /// Disposes of this channel and releases resources.
  Future<void> _dispose() async {
    if (_disposed) return;

    _disposed = true;

    // Unsubscribe if subscribed
    if (_isSubscribed) {
      try {
        await unsubscribe();
      } catch (error) {
        _client._logger.w('Error unsubscribing during dispose: $error');
      }
    }

    // Close streams
    await _messageSubject.close();
    await _presenceSubject.close();

    // Clear history
    _messageHistory.clear();

    _client._logger.d('Disposed channel: $name');
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OddSocketsChannel && other.name == name;
  }

  @override
  int get hashCode => name.hashCode;

  @override
  String toString() => 'OddSocketsChannel(name: $name, subscribed: $_isSubscribed)';
}

/// Extension methods for working with multiple channels.
extension ChannelUtils on OddSocketsClient {
  /// Subscribes to multiple channels with the same handler and options.
  Future<void> subscribeToChannels(
    List<String> channelNames,
    MessageHandler handler, [
    SubscribeOptions? options,
  ]) async {
    final futures = channelNames.map((name) => channel(name).subscribe(handler, options));
    await Future.wait(futures);
  }

  /// Unsubscribes from multiple channels.
  Future<void> unsubscribeFromChannels(List<String> channelNames) async {
    final futures = channelNames.map((name) => channel(name).unsubscribe());
    await Future.wait(futures);
  }

  /// Publishes the same message to multiple channels.
  Future<List<PublishResult>> publishToChannels(
    List<String> channelNames,
    dynamic message, [
    PublishOptions? options,
  ]) async {
    final futures = channelNames.map((name) => channel(name).publish(message, options));
    return Future.wait(futures);
  }

  /// Gets presence information for multiple channels.
  Future<Map<String, PresenceInfo>> getPresenceForChannels(List<String> channelNames) async {
    final futures = channelNames.map((name) async {
      try {
        final presence = await channel(name).getPresence();
        return MapEntry(name, presence);
      } catch (error) {
        // Return empty presence for failed channels
        return MapEntry(name, PresenceInfo(
          channel: name,
          users: [],
          count: 0,
          timestamp: DateTime.now(),
        ));
      }
    });

    final results = await Future.wait(futures);
    return Map.fromEntries(results);
  }
}
