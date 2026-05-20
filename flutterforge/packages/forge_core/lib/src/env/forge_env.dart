enum ForgeEnvironment { dev, staging, prod }

/// ForgeEnv — manages environment configuration for dev/staging/prod.
class ForgeEnv {
  ForgeEnv._();

  static late ForgeEnvironment _env;
  static late Map<String, String> _values;
  static bool _initialized = false;

  static void init({
    ForgeEnvironment environment = ForgeEnvironment.dev,
    Map<String, String> values = const {},
  }) {
    _env = environment;
    _values = values;
    _initialized = true;
  }

  static ForgeEnvironment get current { _assertInit(); return _env; }
  static bool get isDev => current == ForgeEnvironment.dev;
  static bool get isStaging => current == ForgeEnvironment.staging;
  static bool get isProd => current == ForgeEnvironment.prod;

  static String get(String key) {
    _assertInit();
    final value = _values[key];
    if (value == null || value.isEmpty) {
      throw ForgeEnvException(
        'Environment variable "$key" not found or empty. '
        'Did you run: flutter run --dart-define-from-file=.env.dev.json ?',
        key,
      );
    }
    return value;
  }

  static String getOrDefault(String key, String defaultValue) {
    _assertInit();
    final value = _values[key];
    return (value == null || value.isEmpty) ? defaultValue : value;
  }

  static Map<String, String> get all { _assertInit(); return Map.unmodifiable(_values); }

  static void _assertInit() {
    assert(_initialized, 'ForgeEnv not initialized. Call ForgeEnv.init() first.');
  }
}

class ForgeEnvException implements Exception {
  final String message;
  final String key;
  const ForgeEnvException(this.message, this.key);
  @override
  String toString() => 'ForgeEnvException: $message';
}