import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Small synchronous-read key/value store for settings and the session.
/// Backed by shared_preferences in the app (localStorage on web) and by
/// [MemoryStore] in tests.
abstract interface class KeyValueStore {
  String? getString(String key);
  Future<void> setString(String key, String value);
  Future<void> remove(String key);
}

class PrefsStore implements KeyValueStore {
  PrefsStore(this._prefs);

  final SharedPreferencesWithCache _prefs;

  static Future<PrefsStore> create() async =>
      PrefsStore(await SharedPreferencesWithCache.create(cacheOptions: const SharedPreferencesWithCacheOptions()));

  @override
  String? getString(String key) => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) => _prefs.setString(key, value);

  @override
  Future<void> remove(String key) => _prefs.remove(key);
}

class MemoryStore implements KeyValueStore {
  MemoryStore([Map<String, String>? initial]) : values = {...?initial};

  final Map<String, String> values;

  @override
  String? getString(String key) => values[key];

  @override
  Future<void> setString(String key, String value) async => values[key] = value;

  @override
  Future<void> remove(String key) async => values.remove(key);
}

/// Overridden in `main` with a [PrefsStore] and in tests with a [MemoryStore].
final keyValueStoreProvider = Provider<KeyValueStore>((ref) => throw UnimplementedError('keyValueStoreProvider must be overridden'));
