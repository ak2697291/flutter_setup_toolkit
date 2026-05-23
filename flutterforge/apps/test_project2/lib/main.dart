import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_payments/forge_payments.dart';
import 'package:forge_state/forge_state.dart';
import 'package:forge_ui/forge_ui.dart';
import 'package:forge_backend/forge_backend.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'routes.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  ForgeEnv.init(
    environment: ForgeEnvironment.dev,
    values: {
      'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY'),
      'POSTHOG_API_KEY': const String.fromEnvironment('POSTHOG_API_KEY'),
      'RAZORPAY_KEY_ID': const String.fromEnvironment('RAZORPAY_KEY_ID'),
    },
  );

  await ForgeStorage.init();

  await initServiceLocator(modules: [
    BackendModule(
      provider: BackendProvider.supabase,
      supabaseUrl: ForgeEnv.get('SUPABASE_URL'),
      supabaseAnonKey: ForgeEnv.get('SUPABASE_ANON_KEY'),
    ),
    AnalyticsModule(
      providers: [AnalyticsProviderType.posthog],
      posthogApiKey: ForgeEnv.get('POSTHOG_API_KEY'),
    ),
    PaymentsModule(
      providers: [PaymentProvider.razorpay],
      razorpayKeyId: ForgeEnv.get('RAZORPAY_KEY_ID'),
      supabaseUrl: ForgeEnv.get('SUPABASE_URL'),
      supabaseAnonKey: ForgeEnv.get('SUPABASE_ANON_KEY'),
    )
  ]);

  // Load and parse ui_config.yaml, then register in GetIt
  try {
    final yamlString = await rootBundle.loadString('assets/ui_config.yaml');
    final config = ForgeUIConfigLoader.parse(yamlString);
    GetIt.instance.registerSingleton<ForgeUIConfig>(config);
  } catch (e) {
    debugPrint('Failed to load ui_config.yaml: $e. Using standard defaults.');
    GetIt.instance.registerSingleton<ForgeUIConfig>(ForgeUIConfig.fallback());
  }

  ForgeRouter.init(
    routes: appRoutes,
    initialLocation: '/',
  );

  runApp(const TestProject2App());
}

class TestProject2App extends StatelessWidget {
  const TestProject2App({super.key});

  @override
  Widget build(BuildContext context) {
    final uiConfig = GetIt.instance<ForgeUIConfig>();
    final primaryColor = uiConfig.global.primaryColor ?? const Color(0xFF6200EA);

    return ForgeErrorBoundary(
      child: ProviderScope(
        child: MaterialApp.router(
          title: uiConfig.global.appName,
          debugShowCheckedModeBanner: false,
          theme: ForgeTheme.buildLight(primaryColor: primaryColor),
          darkTheme: ForgeTheme.buildDark(primaryColor: primaryColor),
          themeMode: ThemeMode.system,
          routerConfig: ForgeRouter.router,
        ),
      ),
    );
  }
}
