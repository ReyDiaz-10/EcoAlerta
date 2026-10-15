class ApiConfig {
  ApiConfig._();

  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://localhost:8000/api',
  );

  static String get baseUrl => _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');

  static String get publicBaseUrl =>
      baseUrl.replaceFirst(RegExp(r'/api$'), '');

  static Uri get privacyPolicyUrl =>
      Uri.parse('$publicBaseUrl/portal/privacidad.html');

  static Uri endpoint(String path) {
    final normalized = path.startsWith('/') ? path : '/$path';
    return Uri.parse('$baseUrl$normalized');
  }
}
