/// Official Flutter/Dart SDK for OddSockets real-time messaging platform.
///
/// This library provides a comprehensive Flutter SDK for connecting to OddSockets,
/// enabling real-time messaging, presence tracking, and message history features
/// across all Flutter-supported platforms.
///
/// ## Features
///
/// - **Cross-platform**: Works on iOS, Android, Web, Windows, macOS, and Linux
/// - **Real-time messaging**: WebSocket-based real-time communication
/// - **BLoC integration**: Built-in support for flutter_bloc state management
/// - **Stream-based**: Native Dart Stream integration for reactive programming
/// - **Mobile optimized**: Battery-aware reconnection and background handling
/// - **Type-safe**: Full Dart type safety with comprehensive error handling
///
/// ## Quick Start
///
/// ```dart
/// import 'package:oddsockets_flutter/oddsockets_flutter.dart';
///
/// // Create a client
/// final client = OddSocketsClient(
///   OddSocketsConfig.defaultConfig('ak_your_api_key_here'),
/// );
///
/// // Connect and subscribe to a channel
/// await client.connect();
/// final channel = client.channel('my-channel');
/// await channel.subscribe((message) {
///   print('Received: ${message.data}');
/// });
///
/// // Publish a message
/// await channel.publish('Hello, Flutter!');
/// ```
///
/// ## Configuration
///
/// Use the configuration builder for advanced setups:
///
/// ```dart
/// final config = OddSocketsConfig.builder('ak_your_api_key_here')
///     .mobile() // Mobile-optimized settings
///     .heartbeatInterval(Duration(seconds: 45))
///     .reconnectAttempts(10)
///     .build();
///
/// final client = OddSocketsClient(config);
/// ```
///
/// ## BLoC Integration
///
/// The SDK works seamlessly with flutter_bloc:
///
/// ```dart
/// class MessagingBloc extends Bloc<MessagingEvent, MessagingState> {
///   final OddSocketsClient _client;
///   late StreamSubscription _messageSubscription;
///
///   MessagingBloc(this._client) : super(MessagingInitial()) {
///     _messageSubscription = _client.messageStream.listen((message) {
///       add(MessageReceived(message));
///     });
///   }
/// }
/// ```
library oddsockets_flutter;

// Core client and configuration
export 'src/config/oddsockets_config.dart';
export 'src/client/oddsockets_client.dart';
export 'src/client/oddsockets_channel.dart';

// Models and types
export 'src/models/message.dart';
export 'src/models/types.dart';

// Exceptions
export 'src/exceptions/oddsockets_exception.dart';

// Services
export 'src/services/manager_discovery.dart';
export 'src/services/message_size_validator.dart';

// BLoC integration (optional)
export 'src/bloc/oddsockets_bloc.dart' show OddSocketsBloc, OddSocketsEvent, OddSocketsState;

// Utilities
export 'src/utils/connectivity_manager.dart';
export 'src/utils/background_handler.dart';
