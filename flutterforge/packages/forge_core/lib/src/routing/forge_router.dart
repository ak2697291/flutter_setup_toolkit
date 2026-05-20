import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// ForgeRouter — wraps go_router with sensible defaults and auth guard support.
class ForgeRouter {
  ForgeRouter._();

  static GoRouter? _router;

  static GoRouter get router {
    assert(_router != null, 'ForgeRouter not initialized. Call ForgeRouter.init() first.');
    return _router!;
  }

  static void init({
    required List<RouteBase> routes,
    String initialLocation = '/',
    GoRouterRedirect? redirect,
    List<NavigatorObserver> observers = const [],
  }) {
    _router = GoRouter(
      initialLocation: initialLocation,
      routes: routes,
      redirect: redirect,
      observers: observers,
      errorBuilder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text('Page Not Found')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              Text('Route not found: \${state.uri}'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension ForgeNavigation on BuildContext {
  void forgePush(String path, {Object? extra}) => go(path, extra: extra);
  void forgePop() => Navigator.of(this).pop();
  void forgeReplace(String path) => pushReplacement(path);
}