import 'package:logger/logger.dart';

/// Analytics — the single entry point for all analytics tracking.
///
/// Events are automatically forwarded to all registered providers.
///
/// Example:
/// ```dart
/// Analytics.track(
///   'button_clicked',
///   {
///     'screen': 'home',
///     'button': 'signup',
///   },
/// );
///
/// Analytics.identify(
///   userId: '123',
///   properties: {
///     'plan': 'pro',
///   },
/// );
///
/// Analytics.screen('HomeScreen');
/// ```
class Analytics {
  Analytics._();

  static final List<AnalyticsProvider> _providers = [];
  static final Logger _log = Logger();

  static bool _initialized = false;

  /// Initialize analytics providers.
  ///
  /// Called automatically by AnalyticsModule.
  static void init(List<AnalyticsProvider> providers) {
    _providers
      ..clear()
      ..addAll(providers);

    _initialized = true;

    _log.d(
      'Analytics initialized with ${providers.length} provider(s): '
      '${providers.map((e) => e.name).join(', ')}',
    );
  }

  /// Track analytics event.
  static Future<void> track(
    String event, [
    Map<String, dynamic>? properties,
  ]) async {
    _assertInitialized();

    final safeProps = properties ?? {};

    _log.d('ANALYTICS EVENT → $event | $safeProps');

    for (final provider in _providers) {
      try {
        await provider.track(event, safeProps);
      } catch (e, stackTrace) {
        _log.w(
          'Analytics provider ${provider.name} failed for event '
          '$event: $e\n$stackTrace',
        );
      }
    }
  }

  /// Identify logged in user.
  static Future<void> identify({
    required String userId,
    Map<String, dynamic>? properties,
  }) async {
    _assertInitialized();

    final safeProps = properties ?? {};

    _log.d('ANALYTICS IDENTIFY → $userId');

    for (final provider in _providers) {
      try {
        await provider.identify(userId, safeProps);
      } catch (e, stackTrace) {
        _log.w(
          'Analytics identify failed for ${provider.name}: '
          '$e\n$stackTrace',
        );
      }
    }
  }

  /// Track screen navigation.
  static Future<void> screen(
    String screenName, [
    Map<String, dynamic>? properties,
  ]) async {
    _assertInitialized();

    final safeProps = properties ?? {};

    _log.d('ANALYTICS SCREEN → $screenName');

    for (final provider in _providers) {
      try {
        await provider.screen(screenName, safeProps);
      } catch (e, stackTrace) {
        _log.w(
          'Analytics screen failed for ${provider.name}: '
          '$e\n$stackTrace',
        );
      }
    }
  }

  /// Reset analytics session.
  ///
  /// Useful on logout.
  static Future<void> reset() async {
    for (final provider in _providers) {
      try {
        await provider.reset();
      } catch (e, stackTrace) {
        _log.w(
          'Analytics reset failed for ${provider.name}: '
          '$e\n$stackTrace',
        );
      }
    }
  }

  static void _assertInitialized() {
    if (_initialized) return;

    _log.w(
      'Analytics not initialized. '
      'Falling back to ConsoleAnalyticsProvider.',
    );

    init([
      ConsoleAnalyticsProvider(),
    ]);
  }
}

/// Base analytics provider contract.
abstract class AnalyticsProvider {
  String get name;

  Future<void> track(
    String event,
    Map<String, dynamic> properties,
  );

  Future<void> identify(
    String userId,
    Map<String, dynamic> properties,
  );

  Future<void> screen(
    String screenName,
    Map<String, dynamic> properties,
  );

  Future<void> reset();
}

/// ─────────────────────────────────────────────────────────
/// PostHog Provider
/// ─────────────────────────────────────────────────────────

class PostHogAnalyticsProvider implements AnalyticsProvider {
  final dynamic _posthog;

  PostHogAnalyticsProvider(this._posthog);

  @override
  String get name => 'PostHog';

  /// Converts dynamic map into PostHog-compatible map.
 Map<String, Object> _sanitize(
    Map<String, dynamic> properties,
  ) {
    return properties.map(
      (key, value) {
        if (value == null) {
          return MapEntry(key, '');
        }

        if (value is Object) {
          return MapEntry(key, value);
        }

        return MapEntry(key, value.toString());
      },
    );
  }

  @override
  Future<void> track(
    String event,
    Map<String, dynamic> properties,
  ) async {
    await _posthog.capture(
      eventName: event,
      properties: _sanitize(properties),
    );
  }

  @override
  Future<void> identify(
    String userId,
    Map<String, dynamic> properties,
  ) async {
    await _posthog.identify(
      userId: userId,
      userProperties: _sanitize(properties),
    );
  }

  @override
  Future<void> screen(
    String screenName,
    Map<String, dynamic> properties,
  ) async {
    await _posthog.screen(
      screenName: screenName,
      properties: _sanitize(properties),
    );
  }

  @override
  Future<void> reset() async {
    await _posthog.reset();
  }
}

/// ─────────────────────────────────────────────────────────
/// Firebase Analytics Provider
/// ─────────────────────────────────────────────────────────

class FirebaseAnalyticsProvider implements AnalyticsProvider {
  final dynamic _analytics;

  FirebaseAnalyticsProvider(this._analytics);

  @override
  String get name => 'Firebase Analytics';

  @override
  Future<void> track(
    String event,
    Map<String, dynamic> properties,
  ) async {
    final sanitizedEvent = event
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_')
        .substring(
          0,
          event.length > 40 ? 40 : event.length,
        );

    await _analytics.logEvent(
      name: sanitizedEvent,
      parameters: properties.map(
        (key, value) => MapEntry(
          key,
          value?.toString(),
        ),
      ),
    );
  }

  @override
  Future<void> identify(
    String userId,
    Map<String, dynamic> properties,
  ) async {
    await _analytics.setUserId(id: userId);

    for (final entry in properties.entries) {
      await _analytics.setUserProperty(
        name: entry.key,
        value: entry.value?.toString(),
      );
    }
  }

  @override
  Future<void> screen(
    String screenName,
    Map<String, dynamic> properties,
  ) async {
    await _analytics.logScreenView(
      screenName: screenName,
    );
  }

  @override
  Future<void> reset() async {
    await _analytics.setUserId(id: null);
  }
}

/// ─────────────────────────────────────────────────────────
/// Console Analytics Provider
/// ─────────────────────────────────────────────────────────
///
/// Useful for local development/debugging.
class ConsoleAnalyticsProvider implements AnalyticsProvider {
  final Logger _log = Logger();

  @override
  String get name => 'Console';

  @override
  Future<void> track(
    String event,
    Map<String, dynamic> properties,
  ) async {
    _log.d(
      '[Analytics] EVENT → $event | $properties',
    );
  }

  @override
  Future<void> identify(
    String userId,
    Map<String, dynamic> properties,
  ) async {
    _log.d(
      '[Analytics] IDENTIFY → $userId | $properties',
    );
  }

  @override
  Future<void> screen(
    String screenName,
    Map<String, dynamic> properties,
  ) async {
    _log.d(
      '[Analytics] SCREEN → $screenName | $properties',
    );
  }

  @override
  Future<void> reset() async {
    _log.d('[Analytics] RESET');
  }
}