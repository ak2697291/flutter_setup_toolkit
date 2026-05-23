import 'dart:io';
import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;
import '../config/forge_config.dart';

class GenerateCommand extends Command<void> {
  @override
  String get name => 'generate';

  @override
  String get description =>
      'Regenerate main.dart, routes, and DI config from forge.yaml';

  @override
  Future<void> run() async {
    print('\n⚡ FlutterForge Generate\n');

    // Parse forge.yaml
    late ForgeConfig config;
    try {
      config = ForgeConfig.load();
    } on ForgeConfigException catch (e) {
      print('❌ ${e.message}');
      exit(1);
    }

    // Validate
    final errors = config.validate();
    if (errors.isNotEmpty) {
      print('❌ forge.yaml has errors:');
      for (final e in errors) {
        print('   • $e');
      }
      exit(1);
    }

    print('✅ forge.yaml parsed: ${config.app.name}');

    // Generate main.dart
    print('🔧 Generating lib/main.dart...');
    _generateMain(config);

    // Generate routes.dart
    print('🔧 Generating lib/routes.dart...');
    _generateRoutes(config);

    // Generate rbac_config.dart
    if (config.rbac != null) {
      print('🔧 Generating lib/rbac_config.dart...');
      _generateRbac(config);
    }

    // Remind to run build_runner if needed
    if (config.state?.localDb == 'isar') {
      print('\n💡 Run build_runner to generate Isar schemas:');
      print('   flutter pub run build_runner build --delete-conflicting-outputs\n');
    }

    print('✅ Generation complete!\n');
    print('Run the app:');
    print('  flutter run --dart-define-from-file=.env.dev.json\n');
  }

  void _generateMain(ForgeConfig config) {
    final sb = StringBuffer();
    sb.writeln("import 'package:flutter/material.dart';");
    sb.writeln("import 'package:flutter/services.dart';");
    sb.writeln("import 'package:forge_core/forge_core.dart';");
    sb.writeln("import 'package:forge_state/forge_state.dart';");
    sb.writeln("import 'package:forge_ui/forge_ui.dart';");

    if (config.backend != null) {
      sb.writeln("import 'package:forge_backend/forge_backend.dart';");
    }
    if (config.payments != null) {
      sb.writeln("import 'package:forge_payments/forge_payments.dart';");
    }
    if (config.analytics != null) {
      sb.writeln("import 'package:forge_analytics/forge_analytics.dart';");
    }

    sb.writeln("import 'routes.dart';");
    sb.writeln();
    sb.writeln('void main() async {');
    sb.writeln('  WidgetsFlutterBinding.ensureInitialized();');
    sb.writeln();
    sb.writeln('  ForgeEnv.init(');
    sb.writeln('    environment: ForgeEnvironment.dev,');
    sb.writeln('    values: {');

    if (config.backend?.provider == 'supabase') {
      sb.writeln("      'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),");
      sb.writeln("      'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY'),");
    }
    if (config.payments?.razorpay != null) {
      sb.writeln("      'RAZORPAY_KEY_ID': const String.fromEnvironment('RAZORPAY_KEY_ID'),");
    }
    if (config.payments?.stripe != null) {
      sb.writeln("      'STRIPE_KEY': const String.fromEnvironment('STRIPE_KEY'),");
    }
    if (config.analytics?.providers.contains('posthog') == true) {
      sb.writeln("      'POSTHOG_API_KEY': const String.fromEnvironment('POSTHOG_API_KEY'),");
    }
    if (config.analytics?.providers.contains('mixpanel') == true) {
      sb.writeln("      'MIXPANEL_TOKEN': const String.fromEnvironment('MIXPANEL_TOKEN'),");
    }

    if (config.app.developerName != null) {
      sb.writeln("      'DEVELOPER_NAME': '${config.app.developerName}',");
    }
    if (config.app.contactNumber != null) {
      sb.writeln("      'CONTACT_NUMBER': '${config.app.contactNumber}',");
    }

    sb.writeln('    },');
    sb.writeln('  );');
    sb.writeln();
    sb.writeln('  await ForgeStorage.init();');
    sb.writeln();
    sb.writeln('  await initServiceLocator(modules: [');

    // Backend module
    if (config.backend?.provider == 'supabase') {
      sb.writeln('    BackendModule(');
      sb.writeln("      provider: BackendProvider.supabase,");
      sb.writeln("      supabaseUrl: ForgeEnv.get('SUPABASE_URL'),");
      sb.writeln("      supabaseAnonKey: ForgeEnv.get('SUPABASE_ANON_KEY'),");
      sb.writeln('    ),');
    }

    // Payments module
    if (config.payments != null) {
      final providers = config.payments!.providers
          .map((p) => 'PaymentProvider.$p')
          .join(', ');
      sb.writeln('    PaymentsModule(');
      sb.writeln('      providers: [$providers],');
      if (config.payments!.razorpay != null) {
        sb.writeln("      razorpayKeyId: ForgeEnv.get('RAZORPAY_KEY_ID'),");
      }
      if (config.payments!.stripe != null) {
        sb.writeln("      stripePublishableKey: ForgeEnv.get('STRIPE_KEY'),");
      }
      sb.writeln('    ),');
    }

    // Analytics module
    if (config.analytics != null) {
      final providers = config.analytics!.providers
          .map((p) => 'AnalyticsProviderType.$p')
          .join(', ');
      sb.writeln('    AnalyticsModule(');
      sb.writeln('      providers: [$providers],');
      if (config.analytics!.providers.contains('posthog')) {
        sb.writeln("      posthogApiKey: ForgeEnv.get('POSTHOG_API_KEY'),");
        final posthogConfig = config.analytics!.providerConfigs['posthog'];
        if (posthogConfig is Map && posthogConfig.containsKey('host')) {
          final host = posthogConfig['host'];
          sb.writeln("      posthogHost: '$host',");
        }
      }
      if (config.analytics!.providers.contains('mixpanel')) {
        sb.writeln("      mixpanelToken: ForgeEnv.get('MIXPANEL_TOKEN'),");
      }
      sb.writeln('    ),');
    }

    sb.writeln('  ]);');
    sb.writeln();
    sb.writeln('  // Load and parse ui_config.yaml, then register in GetIt');
    sb.writeln('  try {');
    sb.writeln("    final yamlString = await rootBundle.loadString('assets/ui_config.yaml');");
    sb.writeln('    final config = ForgeUIConfigLoader.parse(yamlString);');
    sb.writeln('    GetIt.instance.registerSingleton<ForgeUIConfig>(config);');
    sb.writeln('  } catch (e) {');
    sb.writeln("    debugPrint('Failed to load ui_config.yaml: \$e. Using standard defaults.');");
    sb.writeln('    GetIt.instance.registerSingleton<ForgeUIConfig>(ForgeUIConfig.fallback());');
    sb.writeln('  }');
    sb.writeln();
    sb.writeln('  ForgeRouter.init(');
    sb.writeln('    routes: appRoutes,');
    sb.writeln("    initialLocation: '/',");
    sb.writeln('  );');
    sb.writeln();
    sb.writeln("  runApp(const ${_className(config.app.name)}App());");
    sb.writeln('}');
    sb.writeln();

    // App widget
    sb.writeln("class ${_className(config.app.name)}App extends StatelessWidget {");
    sb.writeln("  const ${_className(config.app.name)}App({super.key});");
    sb.writeln();
    sb.writeln('  @override');
    sb.writeln('  Widget build(BuildContext context) {');
    sb.writeln('    final uiConfig = GetIt.instance<ForgeUIConfig>();');
    sb.writeln("    final primaryColor = uiConfig.global.primaryColor ?? const Color(0xFF${config.app.primaryColor.replaceAll('#', '')});");
    sb.writeln();
    sb.writeln('    return ForgeErrorBoundary(');
    sb.writeln('      child: ProviderScope(');
    sb.writeln('        child: MaterialApp.router(');
    sb.writeln('          title: uiConfig.global.appName,');
    sb.writeln('          debugShowCheckedModeBanner: false,');
    sb.writeln('          theme: ForgeTheme.buildLight(primaryColor: primaryColor),');
    sb.writeln('          darkTheme: ForgeTheme.buildDark(primaryColor: primaryColor),');
    sb.writeln('          themeMode: ThemeMode.system,');
    sb.writeln('          routerConfig: ForgeRouter.router,');
    sb.writeln('        ),');
    sb.writeln('      ),');
    sb.writeln('    );');
    sb.writeln('  }');
    sb.writeln('}');

    final mainFile = File(p.join('lib', 'main.dart'));
    mainFile.writeAsStringSync(sb.toString());
  }

  void _generateRoutes(ForgeConfig config) {
    final file = File(p.join('lib', 'routes.dart'));
    if (file.existsSync()) {
      print('   • lib/routes.dart already exists. Skipping recreation to preserve your custom routes.');
      return;
    }

    final content = '''import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';

// TODO: Import your screen widgets here
// import 'features/home/home_screen.dart';
// import 'features/auth/login_screen.dart';

/// App routes — add your GoRoute definitions here.
/// This file is generated by `forge generate` but safe to edit.
final List<RouteBase> appRoutes = [
  GoRoute(
    path: '/',
    name: 'home',
    builder: (context, state) => const Scaffold(
      body: Center(child: Text('Home — replace with your HomeScreen')),
    ),
  ),
  GoRoute(
    path: '/login',
    name: 'login',
    builder: (context, state) => const Scaffold(
      body: Center(child: Text('Login — replace with your LoginScreen')),
    ),
  ),
];
''';

    file.writeAsStringSync(content);
  }

  void _generateRbac(ForgeConfig config) {
    if (config.rbac == null) return;

    final sb = StringBuffer();
    sb.writeln("import 'package:forge_core/forge_core.dart';");
    sb.writeln();
    sb.writeln("/// App roles defined in forge.yaml");
    sb.writeln("class AppRoles {");

    for (final role in config.rbac!.roles) {
      sb.writeln("  static const $role = ForgeRole('$role');");
    }

    sb.writeln();
    final defaultRole = config.rbac!.defaultRole ?? config.rbac!.roles.first;
    sb.writeln("  static const defaultRole = $defaultRole;");
    sb.writeln("}");

    final file = File(p.join('lib', 'rbac_config.dart'));
    file.writeAsStringSync(sb.toString());
  }

  String _className(String name) =>
      name.split(RegExp(r'[\s_-]+')).map((w) => w[0].toUpperCase() + w.substring(1)).join();
}
