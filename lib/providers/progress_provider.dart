import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/test_result.dart';
import '../services/storage_service.dart';

/// Tracks which questions the user has marked "known", their favorites
/// (starred for extra practice), and the history of completed mock tests.
class ProgressProvider extends ChangeNotifier {
  ProgressProvider(this._storage) {
    _load();
  }

  final StorageService _storage;

  final Map<String, Set<int>> _learned = {};
  final Map<String, Set<int>> _favorites = {};
  List<TestResult> _history = [];

  void _load() {
    for (final version in TestVersion.values) {
      final key = version.storageKey;
      _learned[key] = _storage
          .getStringList(StorageKeys.learned(key))
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
      _favorites[key] = _storage
          .getStringList(StorageKeys.favorites(key))
          .map(int.tryParse)
          .whereType<int>()
          .toSet();
    }
    final raw = _storage.getJsonList(StorageKeys.testHistory);
    if (raw != null) {
      _history = raw
          .whereType<Map<String, dynamic>>()
          .map(TestResult.fromJson)
          .toList();
    }
    notifyListeners();
  }

  Set<int> learnedFor(TestVersion v) => _learned[v.storageKey] ?? {};
  Set<int> favoritesFor(TestVersion v) => _favorites[v.storageKey] ?? {};

  bool isLearned(TestVersion v, int id) => learnedFor(v).contains(id);
  bool isFavorite(TestVersion v, int id) => favoritesFor(v).contains(id);

  int learnedCount(TestVersion v) => learnedFor(v).length;

  Future<void> toggleLearned(TestVersion v, int id) async {
    final set = _learned.putIfAbsent(v.storageKey, () => {});
    set.contains(id) ? set.remove(id) : set.add(id);
    await _storage.setStringList(
      StorageKeys.learned(v.storageKey),
      set.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> setLearned(TestVersion v, int id, bool value) async {
    final set = _learned.putIfAbsent(v.storageKey, () => {});
    if (value) {
      set.add(id);
    } else {
      set.remove(id);
    }
    await _storage.setStringList(
      StorageKeys.learned(v.storageKey),
      set.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> toggleFavorite(TestVersion v, int id) async {
    final set = _favorites.putIfAbsent(v.storageKey, () => {});
    set.contains(id) ? set.remove(id) : set.add(id);
    await _storage.setStringList(
      StorageKeys.favorites(v.storageKey),
      set.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  Future<void> resetLearned(TestVersion v) async {
    _learned[v.storageKey] = {};
    await _storage.remove(StorageKeys.learned(v.storageKey));
    notifyListeners();
  }

  // ---- test history ----
  List<TestResult> get history => List.unmodifiable(_history.reversed);

  List<TestResult> historyFor(TestVersion v) =>
      history.where((r) => r.version == v).toList();

  TestResult? get lastResult => _history.isEmpty ? null : _history.last;

  Future<void> addResult(TestResult result) async {
    _history.add(result);
    // Keep the most recent 100 results.
    if (_history.length > 100) {
      _history = _history.sublist(_history.length - 100);
    }
    await _storage.setJsonList(
      StorageKeys.testHistory,
      _history.map((r) => r.toJson()).toList(),
    );
    notifyListeners();
  }

  Future<void> clearHistory() async {
    _history = [];
    await _storage.remove(StorageKeys.testHistory);
    notifyListeners();
  }
}
