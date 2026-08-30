import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Thin typed wrapper over SharedPreferences for all persisted app state.
class StorageService {
  StorageService(this._prefs);

  final SharedPreferences _prefs;

  static Future<StorageService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return StorageService(prefs);
  }

  // ---- generic helpers ----
  String? getString(String key) => _prefs.getString(key);
  Future<void> setString(String key, String value) =>
      _prefs.setString(key, value);

  bool? getBool(String key) => _prefs.getBool(key);
  Future<void> setBool(String key, bool value) => _prefs.setBool(key, value);

  double? getDouble(String key) => _prefs.getDouble(key);
  Future<void> setDouble(String key, double value) =>
      _prefs.setDouble(key, value);

  Future<void> remove(String key) => _prefs.remove(key);

  Map<String, dynamic>? getJson(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  List<dynamic>? getJsonList(String key) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return jsonDecode(raw) as List<dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<void> setJsonList(String key, List<dynamic> value) =>
      _prefs.setString(key, jsonEncode(value));

  List<String> getStringList(String key) => _prefs.getStringList(key) ?? [];
  Future<void> setStringList(String key, List<String> value) =>
      _prefs.setStringList(key, value);
}

/// Namespaced keys for persisted values.
class StorageKeys {
  static const testVersion = 'settings.testVersion';
  static const darkMode = 'settings.darkMode';
  static const ttsRate = 'settings.ttsRate';
  static const seniorOnly = 'settings.seniorOnly';
  static const officials = 'settings.officials';
  static const congressApiKey = 'settings.congressApiKey';

  static const stateInfo = 'state.info';

  /// One cache entry per state, so switching states does not lose the old one.
  static String stateAnswers(String stateCode) =>
      'state.answers.${stateCode.toUpperCase()}';

  static String learned(String versionKey) => 'progress.learned.$versionKey';
  static String favorites(String versionKey) =>
      'progress.favorites.$versionKey';
  static const testHistory = 'progress.testHistory';

  static const studyPlan = 'studyPlan.current';

  /// A guide fetched from the backend, kept only while it is newer than the
  /// copy bundled with this build.
  static const guide = 'guide.cached';
}
