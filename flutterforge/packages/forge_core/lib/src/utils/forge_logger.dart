import 'package:logger/logger.dart';

class ForgeLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(methodCount: 2, errorMethodCount: 8, colors: true, printEmojis: true),
  );
  static void debug(dynamic message, [dynamic error, StackTrace? st]) => _logger.d(message, error: error, stackTrace: st);
  static void info(dynamic message) => _logger.i(message);
  static void warning(dynamic message, [dynamic error]) => _logger.w(message, error: error);
  static void error(dynamic message, [dynamic error, StackTrace? st]) => _logger.e(message, error: error, stackTrace: st);
}
