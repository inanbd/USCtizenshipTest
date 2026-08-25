import 'package:flutter/foundation.dart';

import '../api/api_exception.dart';
import '../api/civics_api_client.dart';
import '../models/enums.dart';
import 'progress_provider.dart';

/// Keeps local progress and the backend in step.
///
/// Local storage stays the source of truth for the UI, so every study feature
/// keeps working offline and without an account. When the user is signed in,
/// changes are pushed to the server and the server's view is pulled on sign-in
/// so progress follows them to the website and other devices.
class ProgressSync {
  ProgressSync(this._api, this._progress);

  final CivicsApiClient _api;
  final ProgressProvider _progress;

  /// Set when the last sync attempt failed, so the UI can mention it quietly.
  String? lastError;

  bool get _canSync => _api.isSignedIn;

  /// Pulls the server's progress and merges it into local storage.
  ///
  /// The merge is a union: anything marked known or starred on either side
  /// stays marked. That is the forgiving choice for a study app - a user who
  /// learned questions offline should not lose them by signing in.
  Future<void> pull(TestVersion version) async {
    if (!_canSync) return;

    try {
      final json = await _api.fetchProgress(version: version);

      final learned =
          (json['learnedNumbers'] as List?)?.cast<int>() ?? const [];
      final favorites =
          (json['favoriteNumbers'] as List?)?.cast<int>() ?? const [];

      for (final id in learned) {
        await _progress.setLearned(version, id, true);
      }
      for (final id in favorites) {
        if (!_progress.isFavorite(version, id)) {
          await _progress.toggleFavorite(version, id);
        }
      }
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
      debugPrint('Progress pull failed: ${e.message}');
    }
  }

  /// Pushes one question's state to the server. Fire-and-forget by design:
  /// the local change has already been saved, so a failure must not block the UI.
  Future<void> pushQuestion(
    TestVersion version,
    int number, {
    bool? isLearned,
    bool? isFavorite,
  }) async {
    if (!_canSync) return;

    try {
      await _api.setQuestionProgress(
        number: number,
        version: version,
        isLearned: isLearned,
        isFavorite: isFavorite,
      );
      lastError = null;
    } on ApiException catch (e) {
      lastError = e.message;
      debugPrint('Progress push failed: ${e.message}');
    }
  }

  /// Pushes everything currently known locally. Used right after sign-in so a
  /// user who studied offline keeps that work.
  Future<void> pushAll(TestVersion version) async {
    if (!_canSync) return;

    final learned = _progress.learnedFor(version);
    final favorites = _progress.favoritesFor(version);

    for (final number in {...learned, ...favorites}) {
      await pushQuestion(
        version,
        number,
        isLearned: learned.contains(number),
        isFavorite: favorites.contains(number),
      );
    }
  }

  /// Runs the full two-way sync for a version.
  Future<void> syncAll(TestVersion version) async {
    if (!_canSync) return;
    await pushAll(version);
    await pull(version);
  }
}
