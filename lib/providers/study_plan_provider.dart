import 'package:flutter/material.dart';

import '../models/enums.dart';
import '../models/study_plan.dart';
import '../services/storage_service.dart';
import '../services/study_plan_generator.dart';

/// Holds the user's current study plan and day-completion state.
class StudyPlanProvider extends ChangeNotifier {
  StudyPlanProvider(this._storage) {
    _load();
  }

  final StorageService _storage;
  StudyPlan? _plan;

  StudyPlan? get plan => _plan;
  bool get hasPlan => _plan != null;

  void _load() {
    final raw = _storage.getJson(StorageKeys.studyPlan);
    if (raw != null) {
      try {
        _plan = StudyPlan.fromJson(raw);
      } catch (_) {
        _plan = null;
      }
    }
    notifyListeners();
  }

  Future<void> createPlan({
    required TestVersion version,
    required DateTime testDate,
    bool seniorOnly = false,
  }) async {
    _plan = StudyPlanGenerator.generate(
      version: version,
      testDate: testDate,
      seniorOnly: seniorOnly,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> toggleDayComplete(int dayNumber) async {
    final plan = _plan;
    if (plan == null) return;
    final done = Set<int>.from(plan.completedDayNumbers);
    done.contains(dayNumber) ? done.remove(dayNumber) : done.add(dayNumber);
    _plan = plan.copyWith(completedDayNumbers: done);
    await _persist();
    notifyListeners();
  }

  Future<void> clearPlan() async {
    _plan = null;
    await _storage.remove(StorageKeys.studyPlan);
    notifyListeners();
  }

  /// The plan day that falls on today, if any.
  StudyDay? get todayDay {
    final plan = _plan;
    if (plan == null) return null;
    final today = DateTime.now();
    for (final d in plan.days) {
      if (d.date.year == today.year &&
          d.date.month == today.month &&
          d.date.day == today.day) {
        return d;
      }
    }
    return null;
  }

  Future<void> _persist() async {
    final plan = _plan;
    if (plan != null) {
      await _storage.setJson(StorageKeys.studyPlan, plan.toJson());
    }
  }
}
