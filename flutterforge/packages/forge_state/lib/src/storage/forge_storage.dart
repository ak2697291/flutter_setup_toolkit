import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ForgeStorage — unified storage API.
/// Use [ForgeStorage.secure] for sensitive data (tokens, keys).
/// Use [ForgeStorage.prefs] for user preferences.
class ForgeStorage {
  ForgeStorage._();

  static late final FlutterSecureStorage _secure;
  static late final SharedPreferences _prefs;
  static bool _initialized = false;

  static Future<void> init() async {
    _secure = const FlutterSecureStorage(
      aOptions: AndroidOptions(encryptedSharedPreferences: true),
      iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
    );
    _prefs = await SharedPreferences.getInstance();
    _initialized = true;
  }

  // ─── Secure storage (encrypted) ─────────────────────────────────────────

  static Future<void> secureWrite(String key, String value) async {
    _assertInit();
    await _secure.write(key: key, value: value);
  }

  static Future<String?> secureRead(String key) async {
    _assertInit();
    return await _secure.read(key: key);
  }

  static Future<void> secureDelete(String key) async {
    _assertInit();
    await _secure.delete(key: key);
  }

  static Future<void> secureClearAll() async {
    _assertInit();
    await _secure.deleteAll();
  }

  // ─── SharedPreferences (non-sensitive) ──────────────────────────────────

  static Future<bool> setBool(String key, bool value) =>
      _prefs.setBool(key, value);
  static bool? getBool(String key) => _prefs.getBool(key);

  static Future<bool> setString(String key, String value) =>
      _prefs.setString(key, value);
  static String? getString(String key) => _prefs.getString(key);

  static Future<bool> setInt(String key, int value) =>
      _prefs.setInt(key, value);
  static int? getInt(String key) => _prefs.getInt(key);

  static Future<bool> remove(String key) => _prefs.remove(key);

  static Future<bool> clearAll() => _prefs.clear();

  static void _assertInit() {
    assert(_initialized,
        'ForgeStorage not initialized. Call ForgeStorage.init() first.');
  }
}

/// Well-known storage keys to avoid magic strings.
abstract class StorageKeys {
  static const String authToken = 'auth_token';
  static const String refreshToken = 'refresh_token';
  static const String userId = 'user_id';
  static const String onboardingComplete = 'onboarding_complete';
  static const String themeMode = 'theme_mode';
  static const String locale = 'locale';
  static const String lastSyncAt = 'last_sync_at';
}
