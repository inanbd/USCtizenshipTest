/// Where the app talks to the Civics Prep backend.
///
/// Override at build time so the same binary can point at a local server or
/// production:
///
/// ```
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5199
/// ```
///
/// `10.0.2.2` is how the Android emulator reaches the host machine.
class ApiConfig {
  const ApiConfig._();

  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://api.civicsprep.example',
  );

  /// True when [url] points at a real backend rather than the placeholder.
  static bool isRealBaseUrl(String url) =>
      url.isNotEmpty && !url.contains('example');

  /// True when a real backend has been configured for this build.
  static bool get isConfigured => isRealBaseUrl(baseUrl);

  static const Duration timeout = Duration(seconds: 20);
}
