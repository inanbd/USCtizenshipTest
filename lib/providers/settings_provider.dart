import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/officials.dart';
import '../models/state_info.dart';
import '../services/storage_service.dart';

/// App-wide settings: which test, theme, audio speed, current officials, and
/// the user's saved state info.
class SettingsProvider extends ChangeNotifier {
  SettingsProvider(this._storage) {
    _load();
  }

  final StorageService _storage;

  TestVersion _testVersion = TestVersion.v2008;
  ThemeMode _themeMode = ThemeMode.system;
  double _ttsRate = 0.45;
  bool _seniorOnly = false;
  Officials _officials = Officials.defaults;
  String _congressApiKey = '';
  StateInfo? _stateInfo;

  TestVersion get testVersion => _testVersion;
  ThemeMode get themeMode => _themeMode;
  double get ttsRate => _ttsRate;
  bool get seniorOnly => _seniorOnly;
  Officials get officials => _officials;
  String get congressApiKey => _congressApiKey;
  StateInfo? get stateInfo => _stateInfo;

  void _load() {
    final v = _storage.getString(StorageKeys.testVersion);
    _testVersion = v == 'v2020' ? TestVersion.v2020 : TestVersion.v2008;

    final theme = _storage.getString(StorageKeys.darkMode);
    _themeMode = switch (theme) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };

    _ttsRate = _storage.getDouble(StorageKeys.ttsRate) ?? 0.45;
    _seniorOnly = _storage.getBool(StorageKeys.seniorOnly) ?? false;

    final off = _storage.getJson(StorageKeys.officials);
    if (off != null) _officials = Officials.fromJson(off);

    _congressApiKey = _storage.getString(StorageKeys.congressApiKey) ?? '';

    final si = _storage.getJson(StorageKeys.stateInfo);
    if (si != null) _stateInfo = StateInfo.fromJson(si);

    notifyListeners();
  }

  Future<void> setTestVersion(TestVersion version) async {
    if (_testVersion == version) return;
    _testVersion = version;
    await _storage.setString(StorageKeys.testVersion, version.storageKey);
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final value = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await _storage.setString(StorageKeys.darkMode, value);
    notifyListeners();
  }

  Future<void> setTtsRate(double rate) async {
    _ttsRate = rate;
    await _storage.setDouble(StorageKeys.ttsRate, rate);
    notifyListeners();
  }

  Future<void> setSeniorOnly(bool value) async {
    _seniorOnly = value;
    await _storage.setBool(StorageKeys.seniorOnly, value);
    notifyListeners();
  }

  Future<void> setOfficials(Officials officials) async {
    _officials = officials;
    await _storage.setJson(StorageKeys.officials, officials.toJson());
    notifyListeners();
  }

  Future<void> setCongressApiKey(String key) async {
    _congressApiKey = key;
    await _storage.setString(StorageKeys.congressApiKey, key);
    notifyListeners();
  }

  Future<void> setStateInfo(StateInfo? info) async {
    _stateInfo = info;
    if (info == null) {
      await _storage.remove(StorageKeys.stateInfo);
    } else {
      await _storage.setJson(StorageKeys.stateInfo, info.toJson());
    }
    notifyListeners();
  }
}
