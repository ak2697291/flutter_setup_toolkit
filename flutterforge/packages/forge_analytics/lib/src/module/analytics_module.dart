import 'package:forge_core/forge_core.dart';
import 'package:get_it/get_it.dart';
import 'package:forge_core/src/forge_module.dart';
import '../analytics.dart';

enum AnalyticsProviderType { posthog, firebase, mixpanel, console }

class AnalyticsModule implements ForgeModule {
  final List<AnalyticsProviderType> providers;
  final String? posthogApiKey;
  final String? posthogHost;
  final String? mixpanelToken;

  const AnalyticsModule({
    required this.providers,
    this.posthogApiKey,
    this.posthogHost,
    this.mixpanelToken,
  });

  @override
  Future<void> register(GetIt sl) async {
    final providerInstances = <AnalyticsProvider>[];

    for (final type in providers) {
      switch (type) {
        case AnalyticsProviderType.console:
          providerInstances.add(ConsoleAnalyticsProvider());

        case AnalyticsProviderType.posthog:
          if (posthogApiKey == null || posthogApiKey!.isEmpty || posthogApiKey == 'YOUR_POSTHOG_API_KEY') {
            print('⚠️ PostHog: posthogApiKey is missing or set to default placeholder. Skipping PostHog initialization.');
            break;
          }
          // Dynamic import to avoid hard dependency
          try {
            final posthog = await _initPostHog(posthogApiKey!, posthogHost);
            providerInstances.add(PostHogAnalyticsProvider(posthog));
          } catch (e) {
            print('PostHog init failed: $e');
          }

        case AnalyticsProviderType.firebase:
          try {
            // firebase_analytics must already be initialized via Firebase.initializeApp
            final analytics = await _initFirebaseAnalytics();
            providerInstances.add(FirebaseAnalyticsProvider(analytics));
          } catch (e) {
            print('Firebase Analytics init failed: $e');
          }

        case AnalyticsProviderType.mixpanel:
          if (mixpanelToken == null || mixpanelToken!.isEmpty || mixpanelToken == 'YOUR_MIXPANEL_TOKEN') {
            print('⚠️ Mixpanel: mixpanelToken is missing or set to default placeholder. Skipping Mixpanel initialization.');
            break;
          }
          // Mixpanel provider: similar pattern
          break;
      }
    }

    Analytics.init(providerInstances);
  }

  Future<dynamic> _initPostHog(String apiKey, String? host) async {
    // import 'package:posthog_flutter/posthog_flutter.dart';
    // await Posthog().setup(apiKey, host: host ?? 'https://app.posthog.com');
    // return Posthog();
    throw UnimplementedError('Uncomment posthog_flutter import');
  }

  Future<dynamic> _initFirebaseAnalytics() async {
    // import 'package:firebase_analytics/firebase_analytics.dart';
    // return FirebaseAnalytics.instance;
    throw UnimplementedError('Uncomment firebase_analytics import');
  }
}
