import '../api/api_exception.dart';
import '../api/civics_api_client.dart';
import '../data/state_data.dart';
import '../models/state_answers.dart';
import 'congress_api_service.dart';
import 'storage_service.dart';

/// Resolves the state-dependent civics answers and keeps the last payload on
/// the device.
///
/// The backend is the preferred source: it owns the Congress.gov key, holds the
/// maintained governors table, and gives every surface the same answer. Builds
/// with no backend configured (the plain release APK) still work — they fall
/// back to the user's own Congress.gov key, and to the bundled capital when
/// there is no network at all.
class StateAnswersService {
  StateAnswersService(this._api, this._storage, {CongressApiService? congress})
    : _congress = congress ?? CongressApiService();

  final CivicsApiClient _api;
  final StorageService _storage;
  final CongressApiService _congress;

  /// True when this build points at a real backend.
  bool get isBackendConfigured => _api.isBackendConfigured;

  /// The last payload fetched for [stateCode], or null if never fetched.
  StateAnswers? cached(String stateCode) {
    final json = _storage.getJson(StorageKeys.stateAnswers(stateCode));
    if (json == null) return null;
    try {
      return StateAnswers.fromJson(json);
    } catch (_) {
      // A cache written by an older build is not worth crashing over.
      return null;
    }
  }

  /// Fetches fresh answers and caches them.
  ///
  /// [congressApiKey] is the user's own Congress.gov key, used only when the
  /// backend cannot supply the members of Congress itself.
  ///
  /// Throws [ApiException] when nothing could be resolved, so the caller can
  /// offer the cached copy instead.
  Future<StateAnswers> fetch(
    String stateCode, {
    String congressApiKey = '',
  }) async {
    final code = stateCode.toUpperCase();
    final bundled = stateByCode(code);

    StateAnswers? answers;
    String? backendError;

    if (isBackendConfigured) {
      try {
        final json = await _api.fetchStateAnswers(code);
        answers = StateAnswers.fromJson({
          ...json,
          // The server does not date its own response; the cache does, so the
          // user can see how old their copy is.
          'fetchedAt': DateTime.now().toIso8601String(),
        });
      } on ApiException catch (e) {
        backendError = e.message;
      }
    }

    if (answers == null) {
      // The backend is unreachable or absent. Anything fetched before is better
      // than what we can build here, so the cache is the starting point - a
      // failed refresh must never wipe good answers off the device.
      final saved = cached(code);
      if (saved != null) {
        answers = saved.copyWith(
          congressNotice: backendError == null
              ? saved.congressNotice
              : '$backendError Showing the copy saved on this device.',
        );
      } else if (bundled != null) {
        // Nothing saved either, but the bundled capital is still a real answer.
        answers = StateAnswers(
          stateCode: bundled.code,
          stateName: bundled.name,
          capital: bundled.capital,
          isDistrictOfColumbia: bundled.isDistrictOfColumbia,
          congressNotice: backendError,
          fetchedAt: DateTime.now(),
        );
      } else {
        throw ApiException(backendError ?? 'No state with code "$code".');
      }
    }

    // D.C. has no governor and no voting members, so there is nothing to top up.
    if (!answers.isDistrictOfColumbia && !answers.congressAvailable) {
      answers = await _topUpFromCongress(answers, congressApiKey);
    }

    await _storage.setJson(
      StorageKeys.stateAnswers(answers.stateCode),
      answers.toJson(),
    );
    return answers;
  }

  /// Fills in senators and representatives from the user's own Congress.gov
  /// key when the backend could not. Failure here is not fatal: the capital and
  /// governor are still worth returning.
  Future<StateAnswers> _topUpFromCongress(
    StateAnswers answers,
    String apiKey,
  ) async {
    if (apiKey.trim().isEmpty) {
      return answers.copyWith(
        congressNotice:
            answers.congressNotice ??
            'No source for your senators and representative. Add a free '
                'Congress.gov API key in Settings, or type the names in.',
      );
    }

    try {
      final senators = await _congress.fetchSenators(answers.stateCode, apiKey);
      final reps = await _congress.fetchRepresentatives(
        answers.stateCode,
        apiKey,
      );
      return answers.copyWith(
        senators: [
          for (final s in senators)
            CongressMemberAnswer(name: s, chamber: 'Senate'),
        ],
        representatives: [
          for (final r in reps)
            CongressMemberAnswer(
              name: r.name,
              chamber: r.chamber,
              district: r.district,
              party: r.party,
            ),
        ],
        congressAvailable: senators.isNotEmpty || reps.isNotEmpty,
        congressNotice: null,
      );
    } on CongressApiException catch (e) {
      return answers.copyWith(congressNotice: e.message);
    }
  }

  /// Fresh answers if anything can be resolved, otherwise the cached copy.
  /// Returns null only when there is neither.
  Future<StateAnswers?> fetchOrCached(
    String stateCode, {
    String congressApiKey = '',
  }) async {
    try {
      return await fetch(stateCode, congressApiKey: congressApiKey);
    } on ApiException {
      return cached(stateCode);
    }
  }
}
