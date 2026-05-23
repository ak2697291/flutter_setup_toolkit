import 'dart:io';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as p;

/// ForgeConfig — parses and validates forge.yaml
///
/// forge.yaml example:
/// ```yaml
/// app:
///   name: MyApp
///   bundle_id: com.example.myapp
///   platforms: [ios, android, web]
///   primary_color: '#6200EA'
///
/// backend:
///   provider: supabase
///   supabase:
///     url: $SUPABASE_URL
///     anon_key: $SUPABASE_ANON_KEY
///
/// payments:
///   providers: [razorpay, stripe]
///   currency: INR
///   razorpay:
///     key_id: $RAZORPAY_KEY_ID
///   stripe:
///     publishable_key: $STRIPE_KEY
///
/// analytics:
///   providers: [posthog, firebase]
///   posthog:
///     api_key: $POSTHOG_API_KEY
///
/// monitoring:
///   crash: sentry
///   sentry:
///     dsn: $SENTRY_DSN
///
/// state:
///   manager: riverpod
///   local_db: isar
/// ```
class ForgeConfig {
  final AppConfig app;
  final BackendConfig? backend;
  final PaymentsConfig? payments;
  final AnalyticsConfig? analytics;
  final MonitoringConfig? monitoring;
  final StateConfig? state;
  final RbacConfig? rbac;

  ForgeConfig({
    required this.app,
    this.backend,
    this.payments,
    this.analytics,
    this.monitoring,
    this.state,
    this.rbac,
  });

  /// Load and parse forge.yaml from the given directory.
  static ForgeConfig load([String? directory]) {
    final dir = directory ?? Directory.current.path;
    final file = File(p.join(dir, 'forge.yaml'));

    if (!file.existsSync()) {
      throw ForgeConfigException(
        'forge.yaml not found in ${dir}.\n'
        'Run `forge create <app_name>` to scaffold a new project.',
      );
    }

    final content = file.readAsStringSync();
    final yaml = loadYaml(content) as YamlMap;
    return ForgeConfig._fromYaml(yaml);
  }

  factory ForgeConfig._fromYaml(YamlMap yaml) {
    return ForgeConfig(
      app: AppConfig._fromYaml(yaml['app'] as YamlMap),
      backend: yaml.containsKey('backend')
          ? BackendConfig._fromYaml(yaml['backend'] as YamlMap)
          : null,
      payments: yaml.containsKey('payments')
          ? PaymentsConfig._fromYaml(yaml['payments'] as YamlMap)
          : null,
      analytics: yaml.containsKey('analytics')
          ? AnalyticsConfig._fromYaml(yaml['analytics'] as YamlMap)
          : null,
      monitoring: yaml.containsKey('monitoring')
          ? MonitoringConfig._fromYaml(yaml['monitoring'] as YamlMap)
          : null,
      state: yaml.containsKey('state')
          ? StateConfig._fromYaml(yaml['state'] as YamlMap)
          : null,
      rbac: yaml.containsKey('rbac')
          ? RbacConfig._fromYaml(yaml['rbac'] as YamlMap)
          : null,
    );
  }

  /// Validate the config and return a list of warnings/errors.
  List<String> validate() {
    final errors = <String>[];

    if (app.bundleId.isEmpty) errors.add('app.bundle_id is required');
    if (!app.bundleId.contains('.')) {
      errors.add('app.bundle_id must be in reverse-domain format (e.g. com.example.myapp)');
    }

    if (backend?.provider == 'supabase') {
      if (backend!.supabase == null) {
        errors.add('backend.supabase config required when provider is supabase');
      }
    }

    if (payments != null && payments!.providers.contains('razorpay')) {
      if (payments!.razorpay == null) {
        errors.add('payments.razorpay config required when razorpay is in providers');
      }
    }

    if (rbac != null) {
      if (rbac!.roles.isEmpty) {
        errors.add('rbac.roles cannot be empty if rbac section is present');
      }
      if (rbac!.defaultRole != null && !rbac!.roles.contains(rbac!.defaultRole)) {
        errors.add('rbac.default_role "${rbac!.defaultRole}" must be one of the defined roles: ${rbac!.roles}');
      }
    }

    return errors;
  }
}

class AppConfig {
  final String name;
  final String bundleId;
  final List<String> platforms;
  final String primaryColor;
  final String fontFamily;
  final String? developerName;
  final String? contactNumber;

  AppConfig({
    required this.name,
    required this.bundleId,
    required this.platforms,
    this.primaryColor = '#6200EA',
    this.fontFamily = 'Roboto',
    this.developerName,
    this.contactNumber,
  });

  factory AppConfig._fromYaml(YamlMap yaml) => AppConfig(
        name: yaml['name'] as String,
        bundleId: yaml['bundle_id'] as String,
        platforms: (yaml['platforms'] as YamlList?)
                ?.map((e) => e.toString())
                .toList() ??
            ['ios', 'android'],
        primaryColor: (yaml['primary_color'] as String?) ?? '#6200EA',
        fontFamily: (yaml['font_family'] as String?) ?? 'Roboto',
        developerName: yaml['developer_name'] as String?,
        contactNumber: yaml['contact_number'] as String?,
      );
}

class BackendConfig {
  final String provider;
  final SupabaseConfig? supabase;

  BackendConfig({required this.provider, this.supabase});

  factory BackendConfig._fromYaml(YamlMap yaml) => BackendConfig(
        provider: yaml['provider'] as String,
        supabase: yaml.containsKey('supabase')
            ? SupabaseConfig._fromYaml(yaml['supabase'] as YamlMap)
            : null,
      );
}

class SupabaseConfig {
  final String url;
  final String anonKey;

  SupabaseConfig({required this.url, required this.anonKey});

  factory SupabaseConfig._fromYaml(YamlMap yaml) => SupabaseConfig(
        url: yaml['url'] as String,
        anonKey: yaml['anon_key'] as String,
      );
}

class PaymentsConfig {
  final List<String> providers;
  final String currency;
  final RazorpayConfig? razorpay;
  final StripeConfig? stripe;

  PaymentsConfig({
    required this.providers,
    this.currency = 'INR',
    this.razorpay,
    this.stripe,
  });

  factory PaymentsConfig._fromYaml(YamlMap yaml) => PaymentsConfig(
        providers: (yaml['providers'] as YamlList)
            .map((e) => e.toString())
            .toList(),
        currency: (yaml['currency'] as String?) ?? 'INR',
        razorpay: yaml.containsKey('razorpay')
            ? RazorpayConfig._fromYaml(yaml['razorpay'] as YamlMap)
            : null,
        stripe: yaml.containsKey('stripe')
            ? StripeConfig._fromYaml(yaml['stripe'] as YamlMap)
            : null,
      );
}

class RazorpayConfig {
  final String keyId;
  RazorpayConfig({required this.keyId});
  factory RazorpayConfig._fromYaml(YamlMap yaml) =>
      RazorpayConfig(keyId: yaml['key_id'] as String);
}

class StripeConfig {
  final String publishableKey;
  final String? merchantId;
  StripeConfig({required this.publishableKey, this.merchantId});
  factory StripeConfig._fromYaml(YamlMap yaml) => StripeConfig(
        publishableKey: yaml['publishable_key'] as String,
        merchantId: yaml['merchant_id'] as String?,
      );
}

class AnalyticsConfig {
  final List<String> providers;
  final Map<String, dynamic> providerConfigs;

  AnalyticsConfig({required this.providers, required this.providerConfigs});

  factory AnalyticsConfig._fromYaml(YamlMap yaml) => AnalyticsConfig(
        providers: (yaml['providers'] as YamlList)
            .map((e) => e.toString())
            .toList(),
        providerConfigs: Map<String, dynamic>.fromEntries(
          yaml.entries
              .where((e) => e.key != 'providers')
              .map((e) => MapEntry(e.key.toString(), e.value)),
        ),
      );
}

class MonitoringConfig {
  final String? crash;
  final String? performance;
  final String? sentryDsn;

  MonitoringConfig({this.crash, this.performance, this.sentryDsn});

  factory MonitoringConfig._fromYaml(YamlMap yaml) => MonitoringConfig(
        crash: yaml['crash'] as String?,
        performance: yaml['performance'] as String?,
        sentryDsn: (yaml['sentry'] as YamlMap?)?['dsn'] as String?,
      );
}

class StateConfig {
  final String manager;
  final String? localDb;

  StateConfig({required this.manager, this.localDb});

  factory StateConfig._fromYaml(YamlMap yaml) => StateConfig(
        manager: yaml['manager'] as String? ?? 'riverpod',
        localDb: yaml['local_db'] as String?,
      );
}

class RbacConfig {
  final List<String> roles;
  final String? defaultRole;

  RbacConfig({required this.roles, this.defaultRole});

  factory RbacConfig._fromYaml(YamlMap yaml) => RbacConfig(
        roles: (yaml['roles'] as YamlList).map((e) => e.toString()).toList(),
        defaultRole: yaml['default_role'] as String?,
      );
}

class ForgeConfigException implements Exception {
  final String message;
  const ForgeConfigException(this.message);

  @override
  String toString() => 'ForgeConfigException: $message';
}
