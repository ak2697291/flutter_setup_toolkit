import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'routing/forge_router.dart';
import 'theme/forge_theme.dart';
import 'error/forge_error_boundary.dart';

/// ForgeApp — the root widget that wires together all forge modules.
///
/// Usage in main.dart:
/// ```dart
/// void main() async {
///   WidgetsFlutterBinding.ensureInitialized();
///   await ForgeBootstrap.init(config: forgeConfig);
///   runApp(const ForgeApp());
/// }
/// ```
class ForgeApp extends StatelessWidget {
  final String title;
  final Color primaryColor;
  final String? fontFamily;
  final double borderRadius;

  const ForgeApp({
    super.key,
    required this.title,
    this.primaryColor = const Color(0xFF6200EA),
    this.fontFamily,
    this.borderRadius = 12.0,
  });

  @override
  Widget build(BuildContext context) {
    return ForgeErrorBoundary(
      child: ProviderScope(
        child: MaterialApp.router(
          title: title,
          debugShowCheckedModeBanner: false,
          theme: ForgeTheme.buildLight(
              primaryColor: primaryColor,
              fontFamily: fontFamily ?? 'Roboto',
              borderRadius: borderRadius,
          ),
          darkTheme: ForgeTheme.buildDark(

              primaryColor: primaryColor,
              fontFamily: fontFamily ?? 'Roboto',
              borderRadius: borderRadius,
          ),
          themeMode: ThemeMode.system,
          routerConfig: ForgeRouter.router,
        ),
      ),
    );
  }
}
