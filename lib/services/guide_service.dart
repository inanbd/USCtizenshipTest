import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../api/api_exception.dart';
import '../api/civics_api_client.dart';
import '../models/naturalization_guide.dart';
import 'storage_service.dart';

/// Supplies the naturalization process guide.
///
/// The bundled copy is the floor: it ships with the app, so the guide reads on
/// a plane with no signal. The backend serves the same document, and fees and
/// timings do change — so a server copy reviewed more recently than the bundled
/// one wins, and is kept on the device for next time.
class GuideService {
  GuideService(this._api, this._storage);

  final CivicsApiClient _api;
  final StorageService _storage;

  static const assetPath = 'data/naturalization_guide.json';

  NaturalizationGuide? _bundled;

  /// The best guide available without touching the network.
  Future<NaturalizationGuide> current() async {
    final bundled = _bundled ??= await _loadBundled();
    final cached = _cached();
    return _newer(cached, bundled);
  }

  /// Asks the backend for a fresher guide, and remembers it if it is one.
  ///
  /// Never throws: a guide that fails to refresh is not worth interrupting
  /// someone's reading over, and the bundled copy is still correct enough.
  Future<NaturalizationGuide> refresh() async {
    final bundled = _bundled ??= await _loadBundled();

    if (!_api.isBackendConfigured) return _newer(_cached(), bundled);

    try {
      final json = await _api.fetchGuide();
      final fetched = NaturalizationGuide.fromJson(json);
      if (fetched.reviewedOn.isAfter(bundled.reviewedOn)) {
        await _storage.setJson(StorageKeys.guide, json);
        return fetched;
      }
      // The server is not ahead of the bundle, so drop any stale cache.
      await _storage.remove(StorageKeys.guide);
      return bundled;
    } on ApiException {
      return _newer(_cached(), bundled);
    }
  }

  NaturalizationGuide? _cached() {
    final json = _storage.getJson(StorageKeys.guide);
    if (json == null) return null;
    try {
      return NaturalizationGuide.fromJson(json);
    } catch (_) {
      // A cache written by an older build is not worth crashing over.
      return null;
    }
  }

  static NaturalizationGuide _newer(
    NaturalizationGuide? candidate,
    NaturalizationGuide fallback,
  ) {
    if (candidate == null) return fallback;
    return candidate.reviewedOn.isAfter(fallback.reviewedOn)
        ? candidate
        : fallback;
  }

  Future<NaturalizationGuide> _loadBundled() async {
    // Deliberately not rootBundle.loadString: for a file this size it hands the
    // UTF-8 decode to a background isolate, which never settles under the
    // widget-test clock. Decoding the bytes here is synchronous and just as
    // fast for 14 KB.
    final bytes = await rootBundle.load(assetPath);
    final raw = utf8.decode(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
    return NaturalizationGuide.fromJson(
      jsonDecode(raw) as Map<String, dynamic>,
    );
  }
}
