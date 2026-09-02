// OddSockets Flutter SDK - two-client CHALLENGE / leaderboard / achievement /
// directed-invite regression against the live platform.
//
// TWO independent clients (alice + bob), DISTINCT userId, SAME apiKey (shared
// owner scope), both subscribed to 'lobby'. Every cross-client assertion below
// can ONLY be satisfied by a real round-trip through the worker - no mocks, no
// local echo. Room broadcasts arrive wrapped {version,type,identity,challengeId,
// data:{...}}; directed invite/reply/cancel are FLAT.
//
// Runs under `flutter test` (headless flutter_tester). We deliberately do NOT
// call TestWidgetsFlutterBinding.ensureInitialized() (it installs HttpOverrides
// that 400 real network I/O).

import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:oddsockets_flutter/oddsockets_flutter.dart';

void main() {
  test('two-client challenge lifecycle round-trip (live)', () async {
    final apiKey = Platform.environment['OS_KEY'] ??
        Platform.environment['ODDSOCKETS_API_KEY'];
    final managerUrl = Platform.environment['ODDSOCKETS_MANAGER_URL'];
    if (apiKey == null || apiKey.isEmpty) {
      fail('OS_KEY / ODDSOCKETS_API_KEY is not set');
    }
    if (managerUrl == null || managerUrl.isEmpty) {
      fail('ODDSOCKETS_MANAGER_URL is not set');
    }

    final random = Random();
    final challengeId = 'chal-${100000 + random.nextInt(900000)}';
    final achievementId = 'ach-${100000 + random.nextInt(900000)}';
    const channel = 'lobby';

    final results = <String, bool>{};
    void assertion(String name, bool ok, [String extra = '']) {
      results[name] = ok;
      print('  [${ok ? 'PASS' : 'FAIL'}] $name${extra.isEmpty ? '' : '  $extra'}');
    }

    final alice = OddSocketsClient(OddSocketsConfig(
        apiKey: apiKey, userId: 'alice', managerUrl: managerUrl, autoConnect: false));
    final bob = OddSocketsClient(OddSocketsConfig(
        apiKey: apiKey, userId: 'bob', managerUrl: managerUrl, autoConnect: false));

    String? aliceWorker, bobWorker;
    alice.eventStream.listen((e) {
      if (e['type'] == EventType.workerAssigned.name) {
        aliceWorker = e['workerId'] as String?;
        print('[alice] worker $aliceWorker');
      }
    });
    bob.eventStream.listen((e) {
      if (e['type'] == EventType.workerAssigned.name) {
        bobWorker = e['workerId'] as String?;
        print('[bob]   worker $bobWorker');
      }
    });

    // ---- Cross-client inbound completers ----
    final aliceProgressSeen = Completer<Map>();
    final aliceRankChangeSeen = Completer<Map>();
    final bobAchProgressSeen = Completer<Map>();
    final bobAchUnlockSeen = Completer<Map>();
    final bobInviteSeen = Completer<Map>();
    final aliceReplySeen = Completer<Map>();
    final bobCancelSeen = Completer<Map>();
    // Guard: alice must NOT get an unlock banner for the 50% progress step.
    var aliceGotAchUnlockDuringProgress = false;

    // envelope unwrap: room broadcasts -> semantic fields under .data
    Map dataOf(dynamic p) =>
        (p is Map && p['data'] is Map) ? p['data'] as Map : (p is Map ? p : {});

    try {
      print('[connect] connecting both clients via manager $managerUrl ...');
      await alice.connect();
      await bob.connect();
      print('[connect] alice=${alice.connectionState}, bob=${bob.connectionState}');

      // ---- alice room listeners (she watches bob's progress + her own rank) ----
      alice.on('challenge_progress', (p) {
        if (!aliceProgressSeen.isCompleted) aliceProgressSeen.complete(dataOf(p));
      });
      alice.on('leaderboard_rank_change', (p) {
        if (!aliceRankChangeSeen.isCompleted) aliceRankChangeSeen.complete(dataOf(p));
      });

      // ---- bob room listeners (achievement progress vs unlock) ----
      bob.on('achievement_progress', (p) {
        if (!bobAchProgressSeen.isCompleted) bobAchProgressSeen.complete(dataOf(p));
      });
      bob.on('achievement_unlock', (p) {
        if (!bobAchProgressSeen.isCompleted) {
          // an unlock arrived while we only expected progress -> banner leak
          aliceGotAchUnlockDuringProgress = true;
        }
        if (!bobAchUnlockSeen.isCompleted) bobAchUnlockSeen.complete(dataOf(p));
      });

      // ---- directed (FLAT) ----
      bob.on('challenge_invited', (p) {
        if (p is Map && !bobInviteSeen.isCompleted) bobInviteSeen.complete(p);
      });
      alice.on('challenge_reply_received', (p) {
        if (p is Map && !aliceReplySeen.isCompleted) aliceReplySeen.complete(p);
      });
      bob.on('challenge_invite_cancelled', (p) {
        if (p is Map && !bobCancelSeen.isCompleted) bobCancelSeen.complete(p);
      });

      // Both join the lobby room so challenge broadcasts fan out to them.
      await alice.channel(channel).subscribe((_) {}, const SubscribeOptions());
      await bob.channel(channel).subscribe((_) {}, const SubscribeOptions());
      print('[both] subscribed to $channel');

      // 1) createChallenge (alice)
      final createAck = await alice.enhanced.createChallenge({
        'challengeId': challengeId,
        'metric': 'score',
        'ranked': true,
        'channel': channel,
      });
      assertion('1 createChallenge acked',
          createAck['challengeId'] == challengeId, 'ack=$createAck');

      // 2) reportProgress: alice=40, bob=55 -> alice sees challenge_progress + rank_change
      alice.enhanced.reportProgress({
        'challengeId': challengeId,
        'metric': 'score',
        'value': 40,
        'eventId': 'evt-a-${random.nextInt(1 << 32)}',
      });
      bob.enhanced.reportProgress({
        'challengeId': challengeId,
        'metric': 'score',
        'value': 55,
        'eventId': 'evt-b-${random.nextInt(1 << 32)}',
      });

      final prog = await aliceProgressSeen.future.timeout(const Duration(seconds: 12));
      assertion('2a alice sees challenge_progress', prog.isNotEmpty, 'data=$prog');
      final rank = await aliceRankChangeSeen.future.timeout(const Duration(seconds: 12));
      assertion('2b alice sees leaderboard_rank_change', rank.isNotEmpty, 'data=$rank');

      // 3) getStandings (alice): bob@55 rank1, alice@40 rank2, alice yourRank=2
      final standingsRes = await alice.enhanced.getStandings({
        'challengeId': challengeId,
        'limit': 10,
      });
      final standings = (standingsRes['standings'] as List?) ?? const [];
      Map? rowFor(String id) => standings
          .cast<Map>()
          .firstWhere((r) => r['identity'] == id, orElse: () => {});
      final bobRow = rowFor('bob');
      final aliceRow = rowFor('alice');
      final bobOk = bobRow != null && bobRow['value'] == 55 && bobRow['rank'] == 1;
      final aliceOk = aliceRow != null && aliceRow['value'] == 40 && aliceRow['rank'] == 2;
      final yourRankOk = standingsRes['yourRank'] == 2;
      assertion('3 getStandings bob@55#1 alice@40#2 yourRank=2',
          bobOk && aliceOk && yourRankOk, 'res=$standingsRes');

      // 4) completeChallenge: alice(tied)=>finalValue40 rank2, bob(conceded)=>finalValue55 rank1
      final aliceComplete = await alice.enhanced.completeChallenge({
        'challengeId': challengeId,
        'outcome': 'tied',
        'eventId': 'evt-ac-${random.nextInt(1 << 32)}',
      });
      final aliceCompleteOk = aliceComplete['outcome'] == 'tied' &&
          aliceComplete['finalValue'] == 40 &&
          aliceComplete['rank'] == 2;
      assertion('4a alice complete(tied) finalValue40 rank2', aliceCompleteOk,
          'ack=$aliceComplete');

      final bobComplete = await bob.enhanced.completeChallenge({
        'challengeId': challengeId,
        'outcome': 'conceded',
        'eventId': 'evt-bc-${random.nextInt(1 << 32)}',
      });
      final bobCompleteOk = bobComplete['outcome'] == 'conceded' &&
          bobComplete['finalValue'] == 55 &&
          bobComplete['rank'] == 1;
      assertion('4b bob complete(conceded) finalValue55 rank1', bobCompleteOk,
          'ack=$bobComplete');

      // 5) unlockAchievement 50 (alice) -> bob sees achievement_progress in_progress, NO banner
      alice.enhanced.unlockAchievement({
        'achievementId': achievementId,
        'name': 'Halfway',
        'percentComplete': 50,
        'channel': channel,
      });
      final achProg = await bobAchProgressSeen.future.timeout(const Duration(seconds: 12));
      final achProgOk = achProg['status'] == 'in_progress' &&
          !aliceGotAchUnlockDuringProgress;
      assertion('5 bob sees achievement_progress in_progress (no banner)', achProgOk,
          'data=$achProg');

      // 6) unlockAchievement 100 (alice) -> bob sees achievement_unlock unlocked
      alice.enhanced.unlockAchievement({
        'achievementId': achievementId,
        'name': 'Complete',
        'percentComplete': 100,
        'channel': channel,
      });
      final achUnlock = await bobAchUnlockSeen.future.timeout(const Duration(seconds: 12));
      assertion('6 bob sees achievement_unlock unlocked',
          achUnlock['status'] == 'unlocked', 'data=$achUnlock');

      // 7) getAchievements (alice) -> 100 / unlocked
      final achState = await alice.enhanced.getAchievements({'achievementId': achievementId});
      final achList = (achState['achievements'] as List?) ?? const [];
      final myAch = achList.cast<Map>().firstWhere(
          (a) => a['achievementId'] == achievementId, orElse: () => {});
      assertion('7 getAchievements 100/unlocked',
          myAch['percentComplete'] == 100 && myAch['status'] == 'unlocked',
          'ach=$myAch');

      // 8) sendChallengeInvite alice->bob -> bob sees challenge_invited (FLAT) from alice
      final inviteAck = await alice.enhanced.sendChallengeInvite({
        'toUserId': 'bob',
        'type': 'match',
        'payload': {'note': 'ff please'},
        'ttl': 300,
      });
      final inviteId = inviteAck['inviteId'];
      assertion('8a sendChallengeInvite acked pending',
          inviteId != null && inviteAck['toUserId'] == 'bob' &&
              inviteAck['status'] == 'pending', 'ack=$inviteAck');

      final invited = await bobInviteSeen.future.timeout(const Duration(seconds: 12));
      // Wire shape: sender is nested under `from: {userId, identity}` on the
      // directed broadcast (the getChallengeInvites query uses flat fromUserId).
      final invitedFrom = (invited['from'] is Map)
          ? (invited['from']['userId'] ?? invited['from']['identity'])
          : (invited['fromUserId'] ?? invited['fromIdentity'] ?? invited['identity']);
      assertion('8b bob sees challenge_invited from alice',
          invitedFrom == 'alice', 'evt=$invited');

      // 9) bob getChallengeInvites -> lists it
      final invitesRes = await bob.enhanced.getChallengeInvites();
      final invites = (invitesRes['invites'] as List?) ?? const [];
      final listed = invites.cast<Map>().any((i) => i['inviteId'] == inviteId);
      assertion('9 bob getChallengeInvites lists invite', listed, 'invites=$invitesRes');

      // 10) bob reply(accept) -> alice sees challenge_reply_received
      await bob.enhanced.replyChallengeInvite({'inviteId': inviteId, 'accept': true});
      final reply = await aliceReplySeen.future.timeout(const Duration(seconds: 12));
      final replyOk = (reply['inviteId'] == inviteId) &&
          (reply['accept'] == true || reply['accepted'] == true);
      assertion('10 alice sees challenge_reply_received (accept)', replyOk, 'evt=$reply');

      // 11) fresh invite + cancel -> bob sees challenge_invite_cancelled
      final invite2 = await alice.enhanced.sendChallengeInvite({
        'toUserId': 'bob',
        'type': 'match',
        'payload': {'note': 'round2'},
        'ttl': 300,
      });
      final inviteId2 = invite2['inviteId'];
      await alice.enhanced.cancelChallengeInvite({'inviteId': inviteId2});
      final cancelled = await bobCancelSeen.future.timeout(const Duration(seconds: 12));
      assertion('11 bob sees challenge_invite_cancelled',
          cancelled['inviteId'] == inviteId2, 'evt=$cancelled');

      print('\n[workers] alice=$aliceWorker bob=$bobWorker '
          '${aliceWorker != null && aliceWorker == bobWorker ? "(SAME worker)" : "(CROSS worker)"}');
    } finally {
      await alice.disconnect();
      await bob.disconnect();
      await alice.dispose();
      await bob.dispose();
    }

    final failed = results.entries.where((e) => !e.value).map((e) => e.key).toList();
    print('\n=== ${failed.isEmpty ? "ALL PASS" : "FAILURES: $failed"} '
        '(${results.length} assertions) ===');
    expect(failed, isEmpty, reason: 'failed assertions: $failed');
  }, timeout: const Timeout(Duration(seconds: 120)));
}
