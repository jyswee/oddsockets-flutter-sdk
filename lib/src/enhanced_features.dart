import 'dart:async';
import 'client/oddsockets_client.dart';
import 'exceptions/oddsockets_exception.dart';

/// Enhanced Features for OddSockets Flutter SDK
/// Provides 67 new Slack-like events with Dart async/await
class EnhancedFeatures {
  final OddSocketsClient _client;
  final Duration _timeout = const Duration(seconds: 10);

  EnhancedFeatures(this._client);

  // MARK: - Thread Events

  Future<Map<String, dynamic>> threadReply({
    required String channel,
    required String parentMessageId,
    required String message,
    required String userId,
    required String userName,
  }) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'thread_reply') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('thread_reply_success', successHandler);
    _client.once('error', errorHandler);
    
    _client.emit('thread_reply', {
      'channel': channel,
      'parentMessageId': parentMessageId,
      'message': message,
      'userId': userId,
      'userName': userName,
    });

    return completer.future.timeout(_timeout);
  }

  Future<Map<String, dynamic>> getThread(String threadId) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_thread') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('thread_data', successHandler);
    _client.once('error', errorHandler);
    _client.emit('get_thread', {'threadId': threadId});

    return completer.future.timeout(_timeout);
  }

  Future<Map<String, dynamic>> subscribeThread(String threadId, String userId) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'subscribe_thread') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('thread_subscribed', successHandler);
    _client.once('error', errorHandler);
    _client.emit('subscribe_thread', {'threadId': threadId, 'userId': userId});

    return completer.future.timeout(_timeout);
  }

  void markThreadRead(String threadId, String userId) {
    if (!_client.isConnected) return;
    _client.emit('mark_thread_read', {'threadId': threadId, 'userId': userId});
  }

  void followThread(String threadId, String userId) {
    if (!_client.isConnected) return;
    _client.emit('follow_thread', {'threadId': threadId, 'userId': userId});
  }

  void unfollowThread(String threadId, String userId) {
    if (!_client.isConnected) return;
    _client.emit('unfollow_thread', {'threadId': threadId, 'userId': userId});
  }

  // MARK: - Reaction Events

  void addReaction({
    required String messageId,
    required String channel,
    required String emoji,
    required String userId,
    required String userName,
  }) {
    if (!_client.isConnected) return;
    _client.emit('add_reaction', {
      'messageId': messageId,
      'channel': channel,
      'emoji': emoji,
      'userId': userId,
      'userName': userName,
    });
  }

  void removeReaction({
    required String messageId,
    required String channel,
    required String emoji,
    required String userId,
  }) {
    if (!_client.isConnected) return;
    _client.emit('remove_reaction', {
      'messageId': messageId,
      'channel': channel,
      'emoji': emoji,
      'userId': userId,
    });
  }

  Future<Map<String, dynamic>> getReactions(String messageId) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_reactions') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('message_reactions', successHandler);
    _client.once('error', errorHandler);
    _client.emit('get_reactions', {'messageId': messageId});

    return completer.future.timeout(_timeout);
  }

  // MARK: - Read Receipt Events

  void markRead({
    required String messageId,
    required String channel,
    required String userId,
    required String userName,
  }) {
    if (!_client.isConnected) return;
    _client.emit('mark_read', {
      'messageId': messageId,
      'channel': channel,
      'userId': userId,
      'userName': userName,
    });
  }

  Future<Map<String, dynamic>> getUnreadCounts(String userId, List<String> channels) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_unread_counts') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('unread_counts', successHandler);
    _client.once('error', errorHandler);
    _client.emit('get_unread_counts', {'userId': userId, 'channels': channels});

    return completer.future.timeout(_timeout);
  }

  void markAllRead(String channel, String userId) {
    if (!_client.isConnected) return;
    _client.emit('mark_all_read', {'channel': channel, 'userId': userId});
  }

  // MARK: - Channel Events

  Future<Map<String, dynamic>> createChannel({
    required String name,
    required String type,
    required String description,
    required String topic,
    required String createdBy,
    required String createdByName,
  }) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'create_channel') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('channel_create_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('create_channel', {
      'name': name,
      'type': type,
      'description': description,
      'topic': topic,
      'createdBy': createdBy,
      'createdByName': createdByName,
      'members': [],
    });

    return completer.future.timeout(_timeout);
  }

  void updateChannel(String channelId, Map<String, dynamic> updates, String userId) {
    if (!_client.isConnected) return;
    _client.emit('update_channel', {
      'channelId': channelId,
      'updates': updates,
      'userId': userId,
    });
  }

  void archiveChannel(String channelId, String userId) {
    if (!_client.isConnected) return;
    _client.emit('archive_channel', {'channelId': channelId, 'userId': userId});
  }

  void inviteToChannel({
    required String channelId,
    required String invitedUserId,
    required String invitedUserName,
    required String invitedBy,
  }) {
    if (!_client.isConnected) return;
    _client.emit('invite_to_channel', {
      'channelId': channelId,
      'invitedUserId': invitedUserId,
      'invitedUserName': invitedUserName,
      'invitedBy': invitedBy,
    });
  }

  void removeFromChannel(String channelId, String removedUserId, String removedBy) {
    if (!_client.isConnected) return;
    _client.emit('remove_from_channel', {
      'channelId': channelId,
      'removedUserId': removedUserId,
      'removedBy': removedBy,
    });
  }

  void joinChannel(String channelId, String userId, String userName) {
    if (!_client.isConnected) return;
    _client.emit('join_channel', {
      'channelId': channelId,
      'userId': userId,
      'userName': userName,
    });
  }

  void leaveChannel(String channelId, String userId) {
    if (!_client.isConnected) return;
    _client.emit('leave_channel', {'channelId': channelId, 'userId': userId});
  }

  Future<Map<String, dynamic>> getChannelMembers(String channelId) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_channel_members') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('channel_members', successHandler);
    _client.once('error', errorHandler);
    _client.emit('get_channel_members', {'channelId': channelId});

    return completer.future.timeout(_timeout);
  }

  // MARK: - Direct Message Events

  Future<Map<String, dynamic>> createDM(List<String> userIds, String type) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'create_dm') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('dm_create_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('create_dm', {'userIds': userIds, 'type': type});

    return completer.future.timeout(_timeout);
  }

  void sendDM({
    required String conversationId,
    required String message,
    required String userId,
    required String userName,
  }) {
    if (!_client.isConnected) return;
    _client.emit('send_dm', {
      'conversationId': conversationId,
      'message': message,
      'userId': userId,
      'userName': userName,
    });
  }

  Future<Map<String, dynamic>> getDMConversations(String userId, bool includeArchived) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_dm_conversations') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('dm_conversations', successHandler);
    _client.once('error', errorHandler);
    _client.emit('get_dm_conversations', {
      'userId': userId,
      'includeArchived': includeArchived,
    });

    return completer.future.timeout(_timeout);
  }

  // MARK: - Notification Events

  void subscribeNotifications(String userId) {
    if (!_client.isConnected) return;
    _client.emit('subscribe_notifications', {'userId': userId});
  }

  void markNotificationRead(String notificationId, String userId) {
    if (!_client.isConnected) return;
    _client.emit('mark_notification_read', {
      'notificationId': notificationId,
      'userId': userId,
    });
  }

  void markAllNotificationsRead(String userId) {
    if (!_client.isConnected) return;
    _client.emit('mark_all_notifications_read', {'userId': userId});
  }

  void clearNotifications(String userId) {
    if (!_client.isConnected) return;
    _client.emit('clear_notifications', {'userId': userId});
  }

  Future<Map<String, dynamic>> getNotifications(String userId, int limit, [String? status]) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_notifications') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('notifications_data', successHandler);
    _client.once('error', errorHandler);
    
    final params = {'userId': userId, 'limit': limit};
    if (status != null) params['status'] = status;
    
    _client.emit('get_notifications', params);

    return completer.future.timeout(_timeout);
  }

  // MARK: - Presence Events

  void setStatus(String userId, String status) {
    if (!_client.isConnected) return;
    _client.emit('set_status', {'userId': userId, 'status': status});
  }

  void setCustomStatus(String userId, String emoji, String text, [String? expiresAt]) {
    if (!_client.isConnected) return;
    final params = {'userId': userId, 'emoji': emoji, 'text': text};
    if (expiresAt != null) params['expiresAt'] = expiresAt;
    _client.emit('set_custom_status', params);
  }

  void clearCustomStatus(String userId) {
    if (!_client.isConnected) return;
    _client.emit('clear_custom_status', {'userId': userId});
  }

  void setDND(String userId, [String? until]) {
    if (!_client.isConnected) return;
    final params = {'userId': userId};
    if (until != null) params['until'] = until;
    _client.emit('set_dnd', params);
  }

  void clearDND(String userId) {
    if (!_client.isConnected) return;
    _client.emit('clear_dnd', {'userId': userId});
  }

  void startTyping(String userId, String channel) {
    if (!_client.isConnected) return;
    _client.emit('start_typing', {'userId': userId, 'channel': channel});
  }

  void stopTyping(String userId, String channel) {
    if (!_client.isConnected) return;
    _client.emit('stop_typing', {'userId': userId, 'channel': channel});
  }

  Future<Map<String, dynamic>> getUserPresence(List<String> userIds) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_user_presence') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('user_presence_data', successHandler);
    _client.once('error', errorHandler);
    _client.emit('get_user_presence', {'userIds': userIds});

    return completer.future.timeout(_timeout);
  }

  // MARK: - Message Editing Events

  void editMessage(String messageId, String channel, String newContent, String userId) {
    if (!_client.isConnected) return;
    _client.emit('edit_message', {
      'messageId': messageId,
      'channel': channel,
      'newContent': newContent,
      'userId': userId,
    });
  }

  void deleteMessage(String messageId, String channel, String userId) {
    if (!_client.isConnected) return;
    _client.emit('delete_message', {
      'messageId': messageId,
      'channel': channel,
      'userId': userId,
    });
  }

  void pinMessage(String messageId, String channel, String userId) {
    if (!_client.isConnected) return;
    _client.emit('pin_message', {
      'messageId': messageId,
      'channel': channel,
      'userId': userId,
    });
  }

  void unpinMessage(String messageId, String channel, String userId) {
    if (!_client.isConnected) return;
    _client.emit('unpin_message', {
      'messageId': messageId,
      'channel': channel,
      'userId': userId,
    });
  }

  Future<Map<String, dynamic>> getPinnedMessages(String channel) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'get_pinned_messages') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('pinned_messages', successHandler);
    _client.once('error', errorHandler);
    _client.emit('get_pinned_messages', {'channel': channel});

    return completer.future.timeout(_timeout);
  }

  // MARK: - Search Events

  Future<Map<String, dynamic>> searchMessages(String query, String userId, int limit) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'search_messages') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('search_results', successHandler);
    _client.once('error', errorHandler);
    _client.emit('search_messages', {
      'query': query,
      'userId': userId,
      'limit': limit,
    });

    return completer.future.timeout(_timeout);
  }

  Future<Map<String, dynamic>> filterMessages(Map<String, dynamic> filters) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'filter_messages') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('filter_results', successHandler);
    _client.once('error', errorHandler);
    _client.emit('filter_messages', filters);

    return completer.future.timeout(_timeout);
  }

  Future<Map<String, dynamic>> searchInChannel(String channel, String query, int limit) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'search_in_channel') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('channel_search_results', successHandler);
    _client.once('error', errorHandler);
    _client.emit('search_in_channel', {
      'channel': channel,
      'query': query,
      'limit': limit,
    });

    return completer.future.timeout(_timeout);
  }

  Future<Map<String, dynamic>> searchByUser(String userId, [String? query, int limit = 10]) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();
    
    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'search_by_user') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('user_search_results', successHandler);
    _client.once('error', errorHandler);

    final params = {'userId': userId, 'limit': limit};
    if (query != null) params['query'] = query;

    _client.emit('search_by_user', params);

    return completer.future.timeout(_timeout);
  }

  // MARK: - Challenge / Leaderboard / Achievement Events
  //
  // Server-authoritative challenge lifecycle. Progress and completions land on
  // the shared room envelope so every member (and any partner resultWebhookUrl)
  // sees challenge_progress / leaderboard_rank_change / challenge_complete /
  // achievement_unlock — subscribe with client.on('leaderboard_rank_change', ...).

  /// Create (register) a challenge run and its optional result-webhook target.
  ///
  /// [params]: {challengeId, metric, ranked?, channel?, resultWebhookUrl?,
  /// standingsUrl?}. Resolves with {challengeId, metric, ranked, startedAt, channel}.
  Future<Map<String, dynamic>> createChallenge(Map<String, dynamic> params) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'challenge_create') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('challenge_create_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('challenge_create', params);

    return completer.future.timeout(_timeout);
  }

  /// Report a progress value for the connected player. Fire-and-forget: the
  /// server echoes challenge_progress (and leaderboard_rank_change if the player
  /// moved) to the room, which arrives via client.on(...). Pass a stable eventId
  /// to make retries idempotent.
  ///
  /// [params]: {challengeId, value, metric?, eventId?, cohort?, platform?, channel?}.
  void reportProgress(Map<String, dynamic> params) {
    if (!_client.isConnected) return;
    _client.emit('challenge_progress', params);
  }

  /// Complete the connected player's run. Resolves with the server-authoritative
  /// result; the room also receives a challenge_complete broadcast.
  ///
  /// [params]: {challengeId, outcome, eventId?, reward?}. outcome ∈
  /// {completed, failed, expired, conceded, tied} (chess/turn-based mapping:
  /// win=completed+rank1, loss=failed, draw=tied, resign=conceded, timeout=expired).
  /// Resolves with {challengeId, outcome, finalValue, rank}.
  Future<Map<String, dynamic>> completeChallenge(Map<String, dynamic> params) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'challenge_complete') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('challenge_complete_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('challenge_complete', params);

    return completer.future.timeout(_timeout);
  }

  /// Report achievement progress or unlock. Fire-and-forget. Pass percentComplete
  /// (0-100) for progressive achievements: <100 broadcasts achievement_progress
  /// (status in_progress); >=100 or omitted broadcasts achievement_unlock (status
  /// unlocked, banner). State is persisted server-side and queryable via
  /// getAchievements(). Arrives on peers via
  /// client.on('achievement_progress' | 'achievement_unlock', ...).
  ///
  /// [params]: {achievementId, name?, tier?, percentComplete?, challengeId?, channel?}.
  void unlockAchievement(Map<String, dynamic> params) {
    if (!_client.isConnected) return;
    _client.emit('achievement_unlock', params);
  }

  /// Fetch server-ordered leaderboard standings for a ranked challenge. Resolves
  /// with the top-N and the caller's own rank.
  ///
  /// [params]: {challengeId, limit?=20, offset?=0}. Resolves with {challengeId,
  /// metric, standings: [{identity, value, rank, cohort, platform}], yourRank}.
  Future<Map<String, dynamic>> getStandings(Map<String, dynamic> params) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'challenge_standings') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('challenge_standings_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('challenge_standings', params);

    return completer.future.timeout(_timeout);
  }

  /// Query persisted achievement state for the connected player. Pass
  /// achievementId to fetch a single one.
  ///
  /// [params]: {achievementId?}. Resolves with {achievements:
  /// [{achievementId, percentComplete, status, unlockedAt, name, tier}]}.
  Future<Map<String, dynamic>> getAchievements([Map<String, dynamic> params = const {}]) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'achievement_query') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('achievement_state', successHandler);
    _client.once('error', errorHandler);
    _client.emit('achievement_query', params);

    return completer.future.timeout(_timeout);
  }

  /// Send a directed 1:1 challenge/invite to a specific player. The invitee
  /// receives a challenge_invited event via client.on('challenge_invited', ...);
  /// resolves when the server persists it. The invite is stored with a TTL so an
  /// offline player can pull it on reconnect (getChallengeInvites). `type` is
  /// free-form, so the same primitive carries clan/party invites.
  ///
  /// [params]: {toUserId, type?='match', payload?<=8KB, ttl?=300, channel?, inviteId?}.
  /// Resolves with {inviteId, toUserId, type, status:'pending', expiresAt}.
  Future<Map<String, dynamic>> sendChallengeInvite(Map<String, dynamic> params) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'challenge_invite') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('challenge_invite_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('challenge_invite', params);

    return completer.future.timeout(_timeout);
  }

  /// Accept or decline a received invite. The original inviter is notified via
  /// client.on('challenge_reply_received', ...).
  ///
  /// [params]: {inviteId, accept, reason?}. Resolves with {inviteId, accept,
  /// type, payload, channel}.
  Future<Map<String, dynamic>> replyChallengeInvite(Map<String, dynamic> params) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'challenge_reply') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('challenge_reply_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('challenge_reply', params);

    return completer.future.timeout(_timeout);
  }

  /// Cancel a pending invite you sent. The invitee is notified via
  /// client.on('challenge_invite_cancelled', ...).
  ///
  /// [params]: {inviteId}. Resolves with {inviteId}.
  Future<Map<String, dynamic>> cancelChallengeInvite(Map<String, dynamic> params) async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'challenge_invite_cancel') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('challenge_invite_cancel_success', successHandler);
    _client.once('error', errorHandler);
    _client.emit('challenge_invite_cancel', params);

    return completer.future.timeout(_timeout);
  }

  /// Pull the connected player's still-pending invites (e.g. on reconnect).
  ///
  /// Resolves with {invites: [{inviteId, fromUserId, fromIdentity, type, payload,
  /// status, channel, createdAt, expiresAt}]}.
  Future<Map<String, dynamic>> getChallengeInvites() async {
    if (!_client.isConnected) {
      throw const ConnectionException(message: 'Not connected to OddSockets');
    }

    final completer = Completer<Map<String, dynamic>>();

    void successHandler(dynamic data) {
      if (data is Map<String, dynamic>) {
        completer.complete(data);
      }
    }

    void errorHandler(dynamic data) {
      if (data is Map<String, dynamic> && data['event'] == 'challenge_invites_query') {
        completer.completeError(
          MessageDeliveryException(message: data['message']?.toString() ?? 'Unknown error')
        );
      }
    }

    _client.once('challenge_invites', successHandler);
    _client.once('error', errorHandler);
    _client.emit('challenge_invites_query', {});

    return completer.future.timeout(_timeout);
  }
}
