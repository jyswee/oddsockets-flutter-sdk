// OddSockets Flutter SDK - enhanced-events two-client receive-path regression.
//
// TWO independent clients (subscriber "alice" + publisher "bob") on separate
// connections, both subscribed to the same channel. bob fires enhanced
// (Slack-like) actions - startTyping and addReaction. Because alice is on a
// SEPARATE connection, the broadcasts reaching alice's public event stream
// (client.on('user_typing') / client.on('reaction_added')) can ONLY have
// travelled through the worker. No mocks, no local echo.
//
// This proves the enhanced surface is really wired to the live Socket.IO
// transport (client.emit send-path + client.on receive-path), not orphaned.

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oddsockets_flutter/oddsockets_flutter.dart';

void main() {
  test('enhanced broadcasts cross two independent clients (user_typing + reaction_added)',
      () async {
    final apiKey = Platform.environment['ODDSOCKETS_API_KEY'];
    if (apiKey == null || apiKey.isEmpty) {
      fail('ODDSOCKETS_API_KEY is not set');
    }

    final random = Random();
    final channelName = 'enh-${100000 + random.nextInt(900000)}';

    final alice = OddSocketsClient(
      OddSocketsConfig(apiKey: apiKey, userId: 'alice', autoConnect: false),
    );
    final bob = OddSocketsClient(
      OddSocketsConfig(apiKey: apiKey, userId: 'bob', autoConnect: false),
    );

    alice.eventStream.listen((event) {
      if (event['type'] == EventType.workerAssigned.name) {
        print('[alice] worker ${event['workerId']}');
      }
    });
    bob.eventStream.listen((event) {
      if (event['type'] == EventType.workerAssigned.name) {
        print('[bob]   worker ${event['workerId']}');
      }
    });

    final typingSeen = Completer<void>();
    final reactionSeen = Completer<void>();

    try {
      print('[connect] connecting both clients...');
      await alice.connect();
      await bob.connect();
      print('[connect] alice = ${alice.connectionState}, bob = ${bob.connectionState}');

      // alice listens on the PUBLIC enhanced event surface.
      alice.on('user_typing', (data) {
        if (data is Map && data['userId'] == 'bob' && !typingSeen.isCompleted) {
          print("[alice] received 'user_typing' from bob (channel $channelName) "
              '- broadcast round-trip.');
          typingSeen.complete();
        }
      });
      alice.on('reaction_added', (data) {
        if (data is Map && !reactionSeen.isCompleted) {
          final emoji = data['emoji'] ?? data['reaction'];
          print("[alice] received 'reaction_added' ($emoji) from bob "
              '- broadcast round-trip.');
          reactionSeen.complete();
        }
      });

      // Both clients join the same channel room.
      final aliceInbox = alice.channel(channelName);
      await aliceInbox.subscribe((_) {}, const SubscribeOptions(enablePresence: true));
      final bobRoom = bob.channel(channelName);
      await bobRoom.subscribe((_) {}, const SubscribeOptions(enablePresence: true));
      print('[both] subscribed to $channelName');

      // bob fires enhanced actions from its OWN connection.
      print('[bob] enhanced.startTyping(bob) ...');
      bob.enhanced.startTyping('bob', channelName);

      final ack = await bobRoom.publish({'text': 'hi', 'from': 'bob'});
      final messageId = ack.messageId;
      print('[bob] published messageId=$messageId, enhanced.addReaction :thumbsup: ...');
      bob.enhanced.addReaction(
        messageId: messageId ?? 'unknown',
        channel: channelName,
        emoji: ':thumbsup:',
        userId: 'bob',
        userName: 'Bob',
      );

      await Future.wait([
        typingSeen.future.timeout(const Duration(seconds: 15)),
        reactionSeen.future.timeout(const Duration(seconds: 15)),
      ]);

      print('\nOK - enhanced broadcast receive-path verified '
          '(user_typing + reaction_added)');
    } finally {
      await alice.disconnect();
      await bob.disconnect();
      await alice.dispose();
      await bob.dispose();
    }

    expect(typingSeen.isCompleted && reactionSeen.isCompleted, isTrue,
        reason: 'alice never received bob enhanced broadcasts through the worker');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
