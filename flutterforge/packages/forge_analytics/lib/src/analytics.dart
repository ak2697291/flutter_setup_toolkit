import 'package:logger/logger.dart';

/// Analytics — the single entry point for all analytics tracking.
/// Events are fan-out to all configured providers automatically.
///
/// Usage anywhere in your app:
/// ```dart
/// Analytics.track('button_tapped', {'screen': 'home', 'button': 'signup'});
/// Analytics.identify(userId: user.id, properties: {'plan': 'pro'});
/// Analytics.screen('HomeScreen');
/// ```
class Analytics {
  Analytics._();

  static final List<AnalyticsProvider> _providers = [];
  static final Logger _log = Logger();
  static bool _initialized = false;

  /// Register analytics providers. Called by [AnalyticsModule].
  static void init(List<AnalyticsProvider> providers) {
    _providers.clear();
    _providers.addAll(providers);
    _initialized = true;
    _log.d('Analytics initialized with ${providers.length} provider(s): '
        '${providers.map((p) => p.name).join(', ')}');
  }

  /// Track a custom event.
  static Future<void> track(
    String event, [
    Map<String, dynamic>? properties,
  ]) async {
    _assertInitialized();
    _log.d('ANALYTICS: $event ${properties ?? {}}');
    for (final provider in _providers) {
      try {
        await provider.track(event, properties ?? {});
      } catch (e) {
        _log.w('Analytics provider ${provider.name} failed for event $event: $e');
      }
    }
  }

  /// Identify the current user. Call after login.
  static Future<void> identify({
    required String userId,
    Map<String, dynamic>? properties,
  }) async {
    _assertInitialized();
    _log.d('ANALYTICS IDENTIFY: $userId');
    for (final provider in _providers) {
      try {
        await provider.identify(userId, properties ?? {});
      } catch (e) {
        _log.w('Analytics identify failed for ${provider.name}: $e');
      }
    }
  }

  /// Track a screen view.
  static Future<void> screen(String screenName, [Map<String, dynamic>? properties]) async {
    _assertInitialized();
    _log.d('ANALYTICS SCREEN: $screenName');
    for (final provider in _providers) {
      try {
        await provider.screen(screenName, properties ?? {});
      } catch (e) {
        _log.w('Analytics screen failed for ${provider.name}: $e');
      }
    }
  }

  /// Reset analytics state. Call on logout.
  static Future<void> reset() async {
    for (final provider in _providers) {
      try {
        await provider.reset();
      } catch (e) {
        _log.w('Analytics reset failed for ${provider.name}: $e');
      }
    }
  }

  static void _assertInitialized() {
    if (!_initialized) {
      _log.w('Analytics not initialized. Initializing fallback ConsoleAnalyticsProvider.');
      init([ConsoleAnalyticsProvider()]);
    }
  }
}

/// Base class for analytics providers.
abstract class AnalyticsProvider {
  String get name;
  Future<void> track(String event, Map<String, dynamic> properties);
  Future<void> identify(String userId, Map<String, dynamic> properties);
  Future<void> screen(String screenName, Map<String, dynamic> properties);
  Future<void> reset();
}

// ─── PostHog Provider ────────────────────────────────────────────────────────

class PostHogAnalyticsProvider implements AnalyticsProvider {
  // Using dynamic import to avoid compile errors if posthog_flutter is not added
  final dynamic _posthog;

  PostHogAnalyticsProvider(this._posthog);

  @override
  String get name => 'PostHog';

  @override
  Future<void> track(String event, Map<String, dynamic> properties) async {
    await _posthog.capture(eventName: event, properties: properties);
  }

  @override
  Future<void> identify(String userId, Map<String, dynamic> properties) async {
    await _posthog.identify(distinctId: userId, userProperties: properties);
  }

  @override
  Future<void> screen(String screenName, Map<String, dynamic> properties) async {
    await _posthog.screen(screenName: screenName, properties: properties);
  }

  @override
  Future<void> reset() async {
    await _posthog.reset();
  }
}

// ─── Firebase Analytics Provider ─────────────────────────────────────────────

class FirebaseAnalyticsProvider implements AnalyticsProvider {
  final dynamic _analytics;

  FirebaseAnalyticsProvider(this._analytics);

  @override
  String get name => 'Firebase Analytics';

  @override
  Future<void> track(String event, Map<String, dynamic> properties) async {
    await _analytics.logEvent(
      name: event.replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_').substring(0, 40),
      parameters: properties.map((k, v) => MapEntry(k, v.toString())),
    );
  }

  @override
  Future<void> identify(String userId, Map<String, dynamic> properties) async {
    await _analytics.setUserId(id: userId);
    for (final entry in properties.entries) {
      await _analytics.setUserProperty(name: entry.key, value: entry.value.toString());
    }
  }

  @override
  Future<void> screen(String screenName, Map<String, dynamic> properties) async {
    await _analytics.logScreenView(screenName: screenName);
  }

  @override
  Future<void> reset() async {
    await _analytics.setUserId(id: null);
  }
}

// ─── Console provider (dev only) ──────────────────────────────────────────────

class ConsoleAnalyticsProvider implements AnalyticsProvider {
  final Logger _log = Logger();

  @override
  String get name => 'Console';

  @override
  Future<void> track(String event, Map<String, dynamic> properties) async {
    _log.d('[Analytics] $event | $properties');
  }

  @override
  Future<void> identify(String userId, Map<String, dynamic> properties) async {
    _log.d('[Analytics] identify: $userId | $properties');
  }

  @override
  Future<void> screen(String screenName, Map<String, dynamic> properties) async {
    _log.d('[Analytics] screen: $screenName');
  }

  @override
  Future<void> reset() async {
    _log.d('[Analytics] reset');
  }
}
