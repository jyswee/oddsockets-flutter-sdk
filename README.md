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
  config: OddSocketsConfig(apiKey: 'YOUR_API_KEY', userId: 'my-agent'),
);
await client.connect();

final channel = client.channel('my-channel');
channel.subscribe(onMessage: (msg) => print('Received: $msg'));
await channel.publish({'text': 'Hello from Flutter'});
```

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
