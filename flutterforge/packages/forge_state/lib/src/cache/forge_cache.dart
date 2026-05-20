/// ForgeCache — lightweight in-memory cache with TTL support.
/// Sits on top of BackendService to reduce repeated network calls.
///
/// Usage:
/// ```dart
/// final products = await ForgeCache.getOrFetch(
///   key: 'products_list',
///   ttl: Duration(minutes: 5),
///   fetch: () => backend.select(table: 'products'),
/// );
/// ```
class ForgeCache {
  ForgeCache._();

  static final Map<String, _CacheEntry> _store = {};

  /// Get a cached value or fetch and store it.
  static Future<T> getOrFetch<T>({
    required String key,
    required Future<T> Function() fetch,
    Duration ttl = const Duration(minutes: 5),
  }) async {
    final entry = _store[key];
    if (entry != null && !entry.isExpired) {
      return entry.value as T;
    }

    final value = await fetch();
    _store[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
    return value;
  }

  /// Manually set a cache value.
  static void set<T>(String key, T value, {Duration ttl = const Duration(minutes: 5)}) {
    _store[key] = _CacheEntry(value: value, expiresAt: DateTime.now().add(ttl));
  }

  /// Get a cached value without fetching.
  static T? get<T>(String key) {
    final entry = _store[key];
    if (entry == null || entry.isExpired) return null;
    return entry.value as T?;
  }

  /// Invalidate a cache key.
  static void invalidate(String key) {
    _store.remove(key);
  }

  /// Invalidate all keys matching a prefix.
  static void invalidatePrefix(String prefix) {
    _store.removeWhere((key, _) => key.startsWith(prefix));
  }

  /// Clear all cached values.
  static void clear() {
    _store.clear();
  }

  /// Number of entries currently cached.
  static int get size => _store.length;
}

class _CacheEntry {
  final dynamic value;
  final DateTime expiresAt;

  _CacheEntry({required this.value, required this.expiresAt});

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
