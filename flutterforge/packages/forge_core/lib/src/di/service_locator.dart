import 'package:forge_core/src/forge_module.dart';
import 'package:get_it/get_it.dart';
import 'package:logger/logger.dart';


/// Global service locator. Use sl<T>() to resolve dependencies.
final GetIt sl = GetIt.instance;

/// Initialize DI with all forge modules.
/// Call this before runApp() in main.dart.
Future<void> initServiceLocator({
  List<ForgeModule> modules = const [],
}) async {
  sl.registerLazySingleton<Logger>(() => Logger(
    printer: PrettyPrinter(methodCount: 2, errorMethodCount: 8, colors: true, printEmojis: true),
  ));

  for (final module in modules) {
    await module.register(sl);
  }
}

/// Shorthand to resolve a dependency.
T resolve<T extends Object>() => sl<T>();