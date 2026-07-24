# OddSockets Flutter SDK

Official Flutter/Dart SDK for OddSockets real-time messaging platform. Pub/sub, presence, message history. Works on iOS, Android, Web, Desktop.

## Install

```yaml
dependencies:
  oddsockets_flutter: ^1.0.0
```

## Quick Start

```dart
import 'package:oddsockets_flutter/oddsockets_flutter.dart';

final client = OddSocketsClient(
  OddSocketsConfig(apiKey: 'YOUR_API_KEY', userId: 'my-agent'),
);
await client.connect();

final channel = client.channel('my-channel');
await channel.subscribe((msg) => print('Received: ${msg.data}'));
await channel.publish({'text': 'Hello from Flutter'});
```

## Enhanced Features

Beyond core pub/sub, OddSockets ships a Slack-like **enhanced surface** — reactions,
typing indicators, threads, read receipts, presence/status, notifications, DMs,
channel management, message editing and search. It lives on `client.enhanced`.
The pattern is always the same:

1. **Send** an action with a `client.enhanced.*` method (camelCase).
2. **Receive** the paired broadcast with `client.on('<event>', handler)`.

```dart
import 'package:oddsockets_flutter/oddsockets_flutter.dart';

final client = OddSocketsClient(
  OddSocketsConfig(apiKey: 'YOUR_API_KEY', userId: 'alice'),
);
await client.connect();

final channel = client.channel('room-42');
await channel.subscribe((msg) {}, const SubscribeOptions(enablePresence: true));

// Receive-path: broadcasts from other users on the channel
client.on('user_typing',    (data) => print('${data['userId']} is typing'));
client.on('reaction_added', (data) => print('${data['userId']} reacted ${data['emoji']}'));
client.on('thread_reply',   (data) => print('new thread reply'));

// Send-path: enhanced actions over the live socket
client.enhanced.startTyping('alice', 'room-42');
client.enhanced.addReaction(
  messageId: 'msg-1', channel: 'room-42', emoji: ':thumbsup:',
  userId: 'alice', userName: 'Alice',
);
await client.enhanced.threadReply(
  channel: 'room-42', parentMessageId: 'msg-1',
  message: 'Replying in the thread', userId: 'alice', userName: 'Alice',
);
```

Each area exposes methods on `client.enhanced`; the worker broadcasts the paired
events which you handle with `client.on(...)`. Query methods (`get*`, `search*`)
return a `Future<Map<String, dynamic>>` that completes with the worker response.

| Area | Requests (`client.enhanced.*`) | Broadcast events (`client.on`) |
|------|--------------------------------|--------------------------------|
| Typing | `startTyping`, `stopTyping` | `user_typing`, `user_stopped_typing` |
| Reactions | `addReaction`, `removeReaction`, `getReactions` | `reaction_added`, `reaction_removed` |
| Threads | `threadReply`, `getThread`, `subscribeThread`, `followThread`, `markThreadRead` | `thread_reply`, `thread_subscribed`, `thread_followed`, `thread_read_updated` |
| Read receipts | `markRead`, `markAllRead`, `getUnreadCounts` | `user_read`, `unread_count_updated`, `all_marked_read` |
| Messages | `editMessage`, `deleteMessage`, `pinMessage`, `unpinMessage`, `getPinnedMessages`, `searchMessages` | `message_edited`, `message_deleted`, `message_pinned`, `message_unpinned` |
| Presence & status | `setStatus`, `setCustomStatus`, `setDND`, `getUserPresence` | `user_status_changed`, `custom_status_updated`, `dnd_status_changed` |
| Channels | `createChannel`, `updateChannel`, `archiveChannel`, `inviteToChannel`, `joinChannel`, `leaveChannel` | `channel_created`, `channel_updated`, `user_invited`, `user_joined_channel`, `user_left_channel` |
| DMs | `createDM`, `sendDM`, `getDMConversations` | `dm_created`, `dm_received` |
| Notifications | `subscribeNotifications`, `getNotifications`, `markNotificationRead`, `clearNotifications` | `notification`, `notification_read`, `notifications_cleared` |
| Search | `searchMessages`, `searchInChannel`, `searchByUser`, `filterMessages` | (future results) |

For any worker event not wrapped above, subscribe with the raw
`client.on('<event>', handler)` API — all enhanced broadcasts are forwarded onto
the client surface.

## Get a Free API Key

```bash
curl -X POST https://oddsockets.com/api/agent-signup \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com", "agentName": "my-agent", "platform": "flutter"}'
# Verify with 6-digit code:
curl -X POST https://oddsockets.com/api/agent-signup/verify \
  -H "Content-Type: application/json" \
  -d '{"email": "you@example.com", "code": "123456", "agentName": "my-agent"}'
```

## Plans

| | Free | Starter | Pro |
|---|---|---|---|
| **Price** | $0/mo | $49.99/mo | $299/mo |
| **MAU** | 100 | 1,000 | 50,000 |
| **Concurrent connections** | 50 | 1,000 | Unlimited |
| **Messages/day** | 10,000 | 4,320,000 | Unlimited |
| **Channels** | 10 | Unlimited | Unlimited |
| **Storage** | 100MB (24h) | 50GB (6 months) | Unlimited |

## Support

- [Documentation](https://docs.oddsockets.com/sdks/flutter)
- [Issue Tracker](https://github.com/jyswee/oddsockets-flutter-sdk/issues)
- [Email Support](mailto:support@oddsockets.com)

## License

MIT License - Copyright (c) 2026 Joe Wee, Tyga.Cloud Ltd. See [LICENSE](LICENSE) for details.
