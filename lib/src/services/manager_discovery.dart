/// Simple Manager Discovery Service
/// 
/// Always connects to the main manager endpoint which handles
/// all routing and load balancing transparently.
class ManagerDiscovery {
  static const String _managerUrl = 'https://manager1.oddsockets.tyga.network';

  /// Get the manager URL (always returns the main endpoint)
  /// 
  /// [apiKey] The OddSockets API key (not used, kept for compatibility)
  /// Returns the manager URL
  static Future<String> discoverManagerUrl(String apiKey) async {
    return _managerUrl;
  }

  /// Clear cache (no-op, kept for compatibility)
  static void clearCache() {
    // No cache to clear in simplified version
  }

  /// Get the manager URL synchronously
  static String get managerUrl => _managerUrl;
}
