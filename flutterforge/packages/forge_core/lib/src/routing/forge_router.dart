import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../rbac/forge_role.dart';

/// ForgeRoleGuard — helper to handle role-based redirection.
class ForgeRoleGuard {
  /// Returns null if access is allowed, otherwise returns the [redirectLocation].
  static String? redirect({
    required ForgeRole? currentRole,
    required List<ForgeRole> allowedRoles,
    String redirectLocation = '/',
  }) {
    if (currentRole == null || !allowedRoles.contains(currentRole)) {
      return redirectLocation;
    }
    return null;
  }
}

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