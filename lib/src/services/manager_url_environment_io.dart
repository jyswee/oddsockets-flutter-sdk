import 'dart:io' show Platform;

/// Process environment lookup on platforms that have `dart:io`.
String? managerUrlFromEnvironment(String name) => Platform.environment[name];
