# OddSockets Flutter/Dart SDK - Demo

A tiny, runnable program that proves a real real-time round-trip against OddSockets
using **two independent clients**: **connect -> subscribe -> publish -> receive**.

Because the subscriber (`alice`) and the publisher (`bob`) are separate connections,
a message that reaches the subscriber can only have travelled through the OddSockets
worker - so this doubles as an honest end-to-end regression test (no mocks, no local
echo). The SDK speaks genuine Socket.IO (Engine.IO v4) over a WebSocket to the
assigned worker, exactly like the JavaScript and Python SDKs.

## Proof it's real

`demo/PROOF.txt` is a captured transcript of this demo running in Docker against the
live platform. Reproduce it yourself in one command (see below) - here is a real run:

```
[connect] connecting both clients...
[alice] worker w002-oddsockets-1
[bob]   worker w002-oddsockets-1
[connect] alice = Connected, bob = Connected
[alice] subscribed to demo-126109 (presence on)
[bob] published, messageId = d6d5ac6e-8b12-44ac-8bcc-9fb197b8de32
[alice] received bob's message (nonce matched) - real round-trip.
[alice] presence: 1 user(s).
[alice] unsubscribed.

OK - cross-client round-trip verified
```

## 1. Get a free API key

Two-step email verification (no card required):

```bash
# Step 1 - request a code
curl -X POST https://oddsockets.com/api/agent-signup \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","agentName":"demo","platform":"flutter"}'

# Step 2 - verify and receive your apiKey
curl -X POST https://oddsockets.com/api/agent-signup/verify \
  -H "Content-Type: application/json" \
  -d '{"email":"you@example.com","code":"123456","agentName":"demo"}'
```

The verify response contains your `apiKey` (starts with `ak_`).

## 2. Run it in Docker (recommended)

No local Flutter toolchain needed. Build from the repo root so the SDK source is in
context (the demo uses a local path dependency - `oddsockets_flutter: path: ../` - to
compile the SDK straight from the parent, without publishing anything):

```bash
docker build -f demo/Dockerfile -t oddsockets-flutter-demo .
docker run --rm -e ODDSOCKETS_API_KEY="ak_your_key_here" oddsockets-flutter-demo
```

Compilation (and json_serializable codegen) happens at image-build time, so a broken
SDK fails the build - only a genuinely-compiling SDK produces a runnable image. A
successful run prints `OK - cross-client round-trip verified` and exits `0`.

## 2b. Run it locally with the Flutter SDK

Requires the Flutter SDK (stable channel). The demo runs under `flutter test` - not
`dart run` - because the SDK transitively depends on Flutter plugins; `flutter test`
provides the headless `flutter_tester` runtime, so no device or emulator is needed:

```bash
# From the repo root: generate the SDK's json_serializable code once.
flutter pub get
dart run build_runner build --delete-conflicting-outputs

cd demo
flutter pub get
export ODDSOCKETS_API_KEY="ak_your_key_here"
flutter test
```

The key is read from `ODDSOCKETS_API_KEY` and never hardcoded; if it is missing the
test prints the signup instructions above and fails.

## The code, step by step

Create two clients - a subscriber and a publisher - each on its own connection:

```dart
final subscriber = OddSocketsClient(
  OddSocketsConfig(apiKey: apiKey, userId: 'alice', autoConnect: false),
);
final publisher = OddSocketsClient(
  OddSocketsConfig(apiKey: apiKey, userId: 'bob', autoConnect: false),
);

await subscriber.connect();
await publisher.connect();
```

Subscribe on the subscriber (presence enabled):

```dart
final inbox = subscriber.channel('my-channel');
await inbox.subscribe((message) {
  print('received: ${message.data}');
}, const SubscribeOptions(enablePresence: true));
```

Publish from the *other* client - this is what makes the test honest:

```dart
final outbox = publisher.channel('my-channel');
final ack = await outbox.publish({'text': 'hello from bob', 'nonce': nonce});
print('messageId = ${ack.messageId}');
```

Inspect presence, then tear down cleanly:

```dart
final presence = await inbox.getPresence();
print('count: ${presence.count}');
await inbox.unsubscribe();
await subscriber.disconnect();
await publisher.disconnect();
```

## What it demonstrates

- Manager discovery + automatic worker assignment (fully transparent)
- `client.channel(name)` -> `channel.subscribe(cb, opts)` -> `channel.publish(msg)`
- **Cross-client delivery**: a message published by `bob` is delivered to `alice`'s
  subscription in real time - provably through the worker, not a local echo
- Presence tracking, unsubscribe, and graceful disconnect
- A 15-second timeout so a stalled round-trip is reported as a failure (non-zero exit)

## Files

- `Dockerfile` - builds the SDK from source and runs the two-client demo on `ghcr.io/cirruslabs/flutter:stable`.
- `PROOF.txt` - captured transcript of a real containerised run against the platform.
- `test/demo_test.dart` - the two-client round-trip program (a `flutter test`).
- `test/enhanced_test.dart` - two-client enhanced-events regression: bob fires
  `enhanced.startTyping` + `enhanced.addReaction`, alice receives them on her
  public `client.on('user_typing')` / `client.on('reaction_added')` surface -
  provably through the worker (Slack-like events, real receive-path).
- `pubspec.yaml` - resolves the SDK via a local path dependency (`path: ../`).
