import 'package:flutter/material.dart';
import 'package:forge_analytics/forge_analytics.dart';
import 'package:forge_backend/forge_backend.dart';
import 'package:forge_core/forge_core.dart';
import 'package:forge_payments/forge_payments.dart';
import 'package:forge_state/forge_state.dart';

import 'features/auth/login_screen.dart';
import 'features/auth/signup_screen.dart';
import 'features/home/home_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/subscription/subscription_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1️⃣ Load environment config
  ForgeEnv.init(
    environment: ForgeEnvironment.dev,
    values: {
      'SUPABASE_URL': const String.fromEnvironment('SUPABASE_URL'),
      'SUPABASE_ANON_KEY': const String.fromEnvironment('SUPABASE_ANON_KEY'),
      'RAZORPAY_KEY_ID': const String.fromEnvironment('RAZORPAY_KEY_ID'),
      'POSTHOG_API_KEY': const String.fromEnvironment('POSTHOG_API_KEY'),
      'STRIPE_KEY': const String.fromEnvironment('STRIPE_KEY'),
    },
  );

  // 2️⃣ Initialize local storage
  await ForgeStorage.init();

  // 3️⃣ Wire all modules via dependency injection
  await initServiceLocator(modules: [
    BackendModule(
      provider: BackendProvider.supabase,
      supabaseUrl: ForgeEnv.get('SUPABASE_URL'),
      supabaseAnonKey: ForgeEnv.get('SUPABASE_ANON_KEY'),
    ),
    PaymentsModule(
      providers: [PaymentProvider.razorpay],
      razorpayKeyId: ForgeEnv.get('RAZORPAY_KEY_ID'),
      supabaseUrl: ForgeEnv.get('SUPABASE_URL'),
      supabaseAnonKey: ForgeEnv.get('SUPABASE_ANON_KEY'),
    ),
    AnalyticsModule(
      providers: [AnalyticsProviderType.console],
    ),
  ]);

  // 4️⃣ Configure routing with auth guard
  ForgeRouter.init(
    routes: _appRoutes,
    initialLocation: '/',
    redirect: _authGuard,
  );

  runApp(const ExampleApp());
}

String? _authGuard(BuildContext context, GoRouterState state) {
  final sl = GetIt.instance;
  final backend = sl<BackendService>();
  final isLoggedIn = backend.currentUser != null;
  final isAuthRoute = state.uri.path == '/login' || state.uri.path == '/signup';
  if (!isLoggedIn && !isAuthRoute) return '/login';
  if (isLoggedIn && isAuthRoute) return '/';
  return null;
}

final List<RouteBase> _appRoutes = [
  GoRoute(path: '/', name: 'home', builder: (context, state) => const HomeScreen()),
  GoRoute(path: '/login', name: 'login', builder: (context, state) => const LoginScreen()),
  GoRoute(path: '/signup', name: 'signup', builder: (context, state) => const SignupScreen()),
  GoRoute(path: '/profile', name: 'profile', builder: (context, state) => const ProfileScreen()),
  GoRoute(path: '/subscription', name: 'subscription', builder: (context, state) => const SubscriptionScreen()),
];

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ForgeErrorBoundary(
      child: ProviderScope(
        child: MaterialApp.router(
          title: 'ForgeApp',
          debugShowCheckedModeBanner: false,
          theme: ForgeTheme.buildLight(primaryColor: const Color(0xFF6200EA)),
          darkTheme: ForgeTheme.buildDark(primaryColor: const Color(0xFF6200EA)),
          themeMode: ThemeMode.system,
          routerConfig: ForgeRouter.router,
        ),
      ),
    );
  }
}