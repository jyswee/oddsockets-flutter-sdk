/// Process environment lookup for platforms without `dart:io` (notably web),
/// where environment variables do not exist. Always returns null so the caller
/// falls through to its next source.
String? managerUrlFromEnvironment(String name) => null;
