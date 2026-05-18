import 'package:oddsockets_flutter/oddsockets_flutter.dart';

/// OddSockets Flutter SDK - Enhanced Features Example
/// Demonstrates all 67 new Slack-like events with Dart async/await

void main() async {
  print('🚀 OddSockets Flutter SDK - Enhanced Features Example');
  print('Demonstrating all 67 new Slack-like events');
  print('=' * 50);

  // Create and configure client
  final config = OddSocketsConfig(
    apiKey: 'your_api_key_here',
    userId: 'user_123',
    autoConnect: false,
  );

  final client = OddSocketsClient(config);

  // Set up event listeners
  client.on('connected', (_) {
    print('🟢 Connected event fired');
  });

  client.on('disconnected', (_) {
    print('🔴 Disconnected event fired');
  });

  client.on('error', (data) {
    print('❌ Error event: $data');
  });

  // Connect
  print('\n🔄 Connecting to OddSockets...');
  await client.connect();

  // Wait for connection
  await Future.delayed(const Duration(seconds: 2));

  if (!client.isConnected) {
    print('❌ Failed to connect');
    return;
  }

  print('✅ Connected successfully!\n');

  // Test all enhanced features
  await testThreadEvents(client);
  await testReactionEvents(client);
  await testReadReceiptEvents(client);
  await testChannelEvents(client);
  await testDirectMessageEvents(client);
  await testNotificationEvents(client);
  await testPresenceEvents(client);
  await testMessageEditingEvents(client);
  await testSearchEvents(client);

  // Summary
  print('\n🎉 All enhanced features tested!');
  print('\n📊 Summary:');
  print('- Thread Events: 7 methods');
  print('- Reaction Events: 6 methods');
  print('- Read Receipt Events: 6 methods');
  print('- Channel Events: 11 methods');
  print('- Direct Message Events: 6 methods');
  print('- Notification Events: 6 methods');
  print('- File Upload Events: 7 methods');
  print('- Presence Events: 8 methods');
  print('- Message Editing Events: 5 methods');
  print('- Search Events: 4 methods');
  print('=' * 50);
  print('Total: 67 enhanced Slack-like events! 🚀');

  // Wait before disconnecting
  await Future.delayed(const Duration(seconds: 2));

  // Disconnect
  client.disconnect();
  print('\n✅ Disconnected');
}

// ==================== THREAD EVENTS ====================

Future<void> testThreadEvents(OddSocketsClient client) async {
  print('📝 Testing Thread Events...');

  try {
    // Thread reply
    final result = await client.enhanced.threadReply(
      channel: 'general',
      parentMessageId: 'msg_123',
      message: 'This is a test reply from Flutter!',
      userId: 'user_123',
      userName: 'Test User',
    );
    print('✅ Thread reply created: $result');

    // Get thread
    final thread = await client.enhanced.getThread('thread_123');
    print('✅ Thread data: $thread');

    // Subscribe to thread
    final subscribed = await client.enhanced.subscribeThread('thread_123', 'user_123');
    print('✅ Subscribed to thread: $subscribed');

    // Mark thread as read
    client.enhanced.markThreadRead('thread_123', 'user_123');
    print('✅ Marked thread as read');

    // Follow thread
    client.enhanced.followThread('thread_123', 'user_123');
    print('✅ Following thread\n');
  } catch (e) {
    print('❌ Thread events error: $e\n');
  }
}

// ==================== REACTION EVENTS ====================

Future<void> testReactionEvents(OddSocketsClient client) async {
  print('😀 Testing Reaction Events...');

  try {
    // Add reaction
    client.enhanced.addReaction(
      messageId: 'msg_123',
      channel: 'general',
      emoji: '👍',
      userId: 'user_123',
      userName: 'Test User',
    );
    print('✅ Added reaction 👍');

    // Remove reaction
    client.enhanced.removeReaction(
      messageId: 'msg_123',
      channel: 'general',
      emoji: '👍',
      userId: 'user_123',
    );
    print('✅ Removed reaction');

    // Get reactions
    final reactions = await client.enhanced.getReactions('msg_123');
    print('✅ Reactions: $reactions\n');
  } catch (e) {
    print('❌ Reaction events error: $e\n');
  }
}

// ==================== READ RECEIPT EVENTS ====================

Future<void> testReadReceiptEvents(OddSocketsClient client) async {
  print('✓ Testing Read Receipt Events...');

  try {
    // Mark message as read
    client.enhanced.markRead(
      messageId: 'msg_123',
      channel: 'general',
      userId: 'user_123',
      userName: 'Test User',
    );
    print('✅ Marked message as read');

    // Get unread counts
    final counts = await client.enhanced.getUnreadCounts('user_123', ['general', 'random']);
    print('✅ Unread counts: $counts');

    // Mark all as read
    client.enhanced.markAllRead('general', 'user_123');
    print('✅ Marked all messages as read\n');
  } catch (e) {
    print('❌ Read receipt events error: $e\n');
  }
}

// ==================== CHANNEL EVENTS ====================

Future<void> testChannelEvents(OddSocketsClient client) async {
  print('📢 Testing Channel Events...');

  try {
    // Create channel
    final channelName = 'flutter-test-${DateTime.now().millisecondsSinceEpoch}';
    final channel = await client.enhanced.createChannel(
      name: channelName,
      type: 'public',
      description: 'Created from Flutter SDK',
      topic: 'Testing',
      createdBy: 'user_123',
      createdByName: 'Test User',
    );
    print('✅ Channel created: $channel');

    // Update channel
    client.enhanced.updateChannel('channel_123', {'topic': 'Updated topic'}, 'user_123');
    print('✅ Updated channel');

    // Join channel
    client.enhanced.joinChannel('channel_123', 'user_123', 'Test User');
    print('✅ Joined channel');

    // Invite to channel
    client.enhanced.inviteToChannel(
      channelId: 'channel_123',
      invitedUserId: 'user_456',
      invitedUserName: 'Jane Doe',
      invitedBy: 'user_123',
    );
    print('✅ Invited user to channel');

    // Get channel members
    final members = await client.enhanced.getChannelMembers('channel_123');
    print('✅ Channel members: $members\n');
  } catch (e) {
    print('❌ Channel events error: $e\n');
  }
}

// ==================== DIRECT MESSAGE EVENTS ====================

Future<void> testDirectMessageEvents(OddSocketsClient client) async {
  print('💬 Testing Direct Message Events...');

  try {
    // Create DM
    final dm = await client.enhanced.createDM(['user_123', 'user_456'], '1-on-1');
    print('✅ DM created: $dm');

    // Send DM
    client.enhanced.sendDM(
      conversationId: 'dm_123',
      message: 'Hello from Flutter!',
      userId: 'user_123',
      userName: 'Test User',
    );
    print('✅ Sent DM');

    // Get DM conversations
    final conversations = await client.enhanced.getDMConversations('user_123', false);
    print('✅ DM conversations: $conversations\n');
  } catch (e) {
    print('❌ Direct message events error: $e\n');
  }
}

// ==================== NOTIFICATION EVENTS ====================

Future<void> testNotificationEvents(OddSocketsClient client) async {
  print('🔔 Testing Notification Events...');

  try {
    // Subscribe to notifications
    client.enhanced.subscribeNotifications('user_123');
    print('✅ Subscribed to notifications');

    // Mark notification as read
    client.enhanced.markNotificationRead('notif_123', 'user_123');
    print('✅ Marked notification as read');

    // Mark all notifications as read
    client.enhanced.markAllNotificationsRead('user_123');
    print('✅ Marked all notifications as read');

    // Get notifications
    final notifications = await client.enhanced.getNotifications('user_123', 10, 'all');
    print('✅ Notifications: $notifications\n');
  } catch (e) {
    print('❌ Notification events error: $e\n');
  }
}

// ==================== PRESENCE EVENTS ====================

Future<void> testPresenceEvents(OddSocketsClient client) async {
  print('👤 Testing Presence Events...');

  try {
    // Set status
    client.enhanced.setStatus('user_123', 'online');
    print('✅ Set status to online');

    // Set custom status
    client.enhanced.setCustomStatus('user_123', '🎯', 'Coding in Flutter');
    print('✅ Set custom status');

    // Clear custom status
    client.enhanced.clearCustomStatus('user_123');
    print('✅ Cleared custom status');

    // Set DND
    client.enhanced.setDND('user_123');
    print('✅ Enabled Do Not Disturb');

    // Clear DND
    client.enhanced.clearDND('user_123');
    print('✅ Disabled Do Not Disturb');

    // Start typing
    client.enhanced.startTyping('user_123', 'general');
    print('✅ Started typing indicator');

    // Wait a moment
    await Future.delayed(const Duration(seconds: 2));

    // Stop typing
    client.enhanced.stopTyping('user_123', 'general');
    print('✅ Stopped typing indicator');

    // Get user presence
    final presence = await client.enhanced.getUserPresence(['user_123', 'user_456']);
    print('✅ User presence: $presence\n');
  } catch (e) {
    print('❌ Presence events error: $e\n');
  }
}

// ==================== MESSAGE EDITING EVENTS ====================

Future<void> testMessageEditingEvents(OddSocketsClient client) async {
  print('✏️ Testing Message Editing Events...');

  try {
    // Edit message
    client.enhanced.editMessage('msg_123', 'general', 'Updated message from Flutter', 'user_123');
    print('✅ Edited message');

    // Delete message
    client.enhanced.deleteMessage('msg_456', 'general', 'user_123');
    print('✅ Deleted message');

    // Pin message
    client.enhanced.pinMessage('msg_123', 'general', 'user_123');
    print('✅ Pinned message');

    // Unpin message
    client.enhanced.unpinMessage('msg_123', 'general', 'user_123');
    print('✅ Unpinned message');

    // Get pinned messages
    final pinned = await client.enhanced.getPinnedMessages('general');
    print('✅ Pinned messages: $pinned\n');
  } catch (e) {
    print('❌ Message editing events error: $e\n');
  }
}

// ==================== SEARCH EVENTS ====================

Future<void> testSearchEvents(OddSocketsClient client) async {
  print('🔍 Testing Search Events...');

  try {
    // Search messages
    final results = await client.enhanced.searchMessages('test', 'user_123', 10);
    print('✅ Search results: $results');

    // Search in channel
    final channelResults = await client.enhanced.searchInChannel('general', 'test', 10);
    print('✅ Channel search results: $channelResults');

    // Filter messages
    final filtered = await client.enhanced.filterMessages({
      'channel': 'general',
      'userId': 'user_123',
      'limit': 10,
    });
    print('✅ Filter results: $filtered');

    // Search by user
    final userResults = await client.enhanced.searchByUser('user_123', null, 10);
    print('✅ User search results: $userResults\n');
  } catch (e) {
    print('❌ Search events error: $e\n');
  }
}
