import 'manager_url_environment.dart'
    if (dart.library.io) 'manager_url_environment_io.dart';

/// Resolves the manager endpoint used for worker assignment.
///
/// A manager pointed at the wrong cluster still answers happily, so silently
/// substituting a default would connect a self-hosted or QA deployment to
/// production without any visible symptom. The configured value is therefore
/// used verbatim, and the default endpoint applies only when nothing has been
/// configured at all - never as a recovery path for an unreachable manager.
class ManagerDiscovery {
  /// The endpoint used when no manager URL has been configured anywhere.
  static const String defaultManagerUrl =
      'https://connect.oddsockets.tyga.network';

  /// Environment variable consulted when no manager URL is configured.
  static const String managerUrlEnvVar = 'ODDSOCKETS_MANAGER_URL';

  /// Resolves the manager URL to use.
  ///
  /// Precedence: [configuredUrl], then the `ODDSOCKETS_MANAGER_URL`
  /// environment variable (unavailable on web), then [defaultManagerUrl].
  ///
  /// Throws [ArgumentError] if the resolved value is not an absolute http(s)
  /// URL.
  static String resolveManagerUrl(String? configuredUrl) {
    final configured = configuredUrl?.trim();
    if (configured != null && configured.isNotEmpty) {
      return normalizeManagerUrl(configured);
    }

    final fromEnvironment = managerUrlFromEnvironment(managerUrlEnvVar)?.trim();
    if (fromEnvironment != null && fromEnvironment.isNotEmpty) {
      return normalizeManagerUrl(fromEnvironment);
    }

    return defaultManagerUrl;
  }

  /// Validates a manager URL and strips any trailing slashes.
  ///
  /// Throws [ArgumentError] if it is not an absolute http(s) URL.
  static String normalizeManagerUrl(String url) {
    var candidate = url.trim();
    while (candidate.endsWith('/')) {
      candidate = candidate.substring(0, candidate.length - 1);
    }

    final uri = Uri.tryParse(candidate);
    final isAbsoluteHttp = uri != null &&
        (uri.isScheme('http') || uri.isScheme('https')) &&
        uri.host.isNotEmpty;

    if (!isAbsoluteHttp) {
      throw ArgumentError('Invalid managerUrl: $url');
    }

    return candidate;
  }
}
