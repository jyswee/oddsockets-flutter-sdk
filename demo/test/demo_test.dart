// OddSockets Flutter SDK - two-client round-trip demo, run as a flutter test.
//
// A genuine end-to-end round-trip using TWO independent clients:
//   - a SUBSCRIBER (user "alice") that listens on a channel
//   - a PUBLISHER  (user "bob")   that sends one message
//
// Because they are separate connections, a message reaching the subscriber can
// ONLY have travelled through the OddSockets worker - it cannot be a local echo.
// A matched nonce here is proof of a real Socket.IO round-trip. No mocks.
//
// Exercised surface: connect -> subscribe (+presence) -> publish -> receive
// -> presence -> unsubscribe -> disconnect.
//
// It runs under `flutter test` (not `dart run`) because the SDK depends on the
// Flutter SDK; flutter test provides the headless runtime without a device.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oddsockets_flutter/oddsockets_flutter.dart';

// NB: we deliberately do NOT call TestWidgetsFlutterBinding.ensureInitialized()
// - it installs HttpOverrides that block real network I/O (every request 400s),
// which would stop the demo reaching the live platform. The plain test binding
// makes real HTTP + WebSocket calls; the SDK guards its lone platform-channel
// touch point (connectivity) so it runs headless.
void main() {
  test('two independent clients complete a cross-delivery round-trip', () async {
    final apiKey = Platform.environment['ODDSOCKETS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      _printSignupInstructions();
      fail('ODDSOCKETS_API_KEY is not set');
    }

    // A unique channel and nonce so we only ever match our own run.
    final random = Random();
    final channelName = 'demo-${100000 + random.nextInt(900000)}';
    final nonce = 'n-${random.nextInt(1 << 32).toRadixString(16)}';

    // Two independent clients on the same platform.
    final subscriber = OddSocketsClient(
      OddSocketsConfig(apiKey: apiKey, userId: 'alice', autoConnect: false),
    );
    final publisher = OddSocketsClient(
      OddSocketsConfig(apiKey: apiKey, userId: 'bob', autoConnect: false),
    );

    subscriber.eventStream.listen((event) {
      if (event['type'] == EventType.workerAssigned.name) {
        print('[alice] worker ${event['workerId']}');
      }
    });
    publisher.eventStream.listen((event) {
      if (event['type'] == EventType.workerAssigned.name) {
        print('[bob]   worker ${event['workerId']}');
      }
    });

    // Completed as soon as alice sees bob's message (matching nonce).
    final roundTrip = Completer<void>();

    try {
      print('[connect] connecting both clients...');
      await subscriber.connect();
      await publisher.connect();
      print('[connect] alice = ${subscriber.connectionState}, '
          'bob = ${publisher.connectionState}');

      // Subscriber joins with presence enabled.
      final inbox = subscriber.channel(channelName);
      await inbox.subscribe((message) {
        final data = message.data;
        final received = data is Map ? data['nonce'] : null;
        if (received == nonce && !roundTrip.isCompleted) {
          print("[alice] received bob's message (nonce matched) - real round-trip.");
          roundTrip.complete();
        }
      }, const SubscribeOptions(enablePresence: true));
      print('[alice] subscribed to $channelName (presence on)');

      // Publisher sends from its OWN connection.
      final outbox = publisher.channel(channelName);
      final ack = await outbox.publish({
        'text': 'hello from bob',
        'nonce': nonce,
        'from': 'bob',
      });
      print('[bob] published, messageId = ${ack.messageId}');

      // Wait for the cross-client delivery.
      await roundTrip.future.timeout(const Duration(seconds: 15));

      // Inspect presence, then tear down cleanly.
      final presence = await inbox.getPresence();
      print('[alice] presence: ${presence.count} user(s).');
      await inbox.unsubscribe();
      print('[alice] unsubscribed.');

      print('\nOK - cross-client round-trip verified');
    } finally {
      await subscriber.disconnect();
      await publisher.disconnect();
      await subscriber.dispose();
      await publisher.dispose();
    }

    expect(roundTrip.isCompleted, isTrue,
        reason: 'alice never received bob\'s message through the worker');
  }, timeout: const Timeout(Duration(seconds: 60)));
}

void _printSignupInstructions() {
  stderr.writeln('''
ODDSOCKETS_API_KEY is not set.

Get a free API key (two-step, no card required):

  curl -X POST https://oddsockets.com/api/agent-signup \\
    -H "Content-Type: application/json" \\
    -d '{"email": "you@example.com", "agentName": "flutter-demo", "platform": "flutter"}'

  # A 6-digit code is emailed to you. Verify it:
  curl -X POST https://oddsockets.com/api/agent-signup/verify \\
    -H "Content-Type: application/json" \\
    -d '{"email": "you@example.com", "code": "123456", "agentName": "flutter-demo"}'

Then export the returned key and run again:

  export ODDSOCKETS_API_KEY=ak_your_key_here
  flutter test
''');
}
