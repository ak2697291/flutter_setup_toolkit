/// FlutterForge Core — the mandatory foundation package.
/// Exports DI, routing, theming, environment config, and error handling.
library forge_core;

export 'src/di/service_locator.dart';
export 'src/routing/forge_router.dart';
export 'src/theme/forge_theme.dart';
export 'src/env/forge_env.dart';
export 'src/error/forge_error.dart';
export 'src/error/forge_error_boundary.dart';
export 'src/utils/forge_logger.dart';
export 'package:get_it/get_it.dart';
export 'package:go_router/go_router.dart';
export 'package:flutter_riverpod/flutter_riverpod.dart';
