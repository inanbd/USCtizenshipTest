import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Live refresh of state-dependent civics answers from the official
/// Congress.gov API (https://api.congress.gov).
///
/// This is the "live" half of the hybrid state-data strategy: bundled data
/// (state capitals) works offline, and the current U.S. senators / house
/// members for a state can be pulled on demand. The Congress.gov API requires
/// a free API key (get one at https://api.congress.gov/sign-up/), which the
/// user enters in Settings. When no key is set, the app relies on bundled +
/// manually entered data instead.
class CongressApiService {
  CongressApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;
  static const _base = 'https://api.congress.gov/v3';

  /// Fetches the current U.S. senators for [stateCode] (e.g. "CA").
  /// Returns their display names, or throws [CongressApiException] on failure.
  Future<List<String>> fetchSenators(String stateCode, String apiKey) async {
    final members = await _fetchMembers(stateCode, apiKey);
    return members
        .where((m) => (m.chamber).toLowerCase().contains('senate'))
        .map((m) => m.name)
        .toList();
  }

  /// Fetches the current U.S. House members for [stateCode]. Because the
  /// correct representative depends on the applicant's congressional district,
  /// the caller should let the user pick the right one from this list.
  Future<List<CongressMember>> fetchRepresentatives(
    String stateCode,
    String apiKey,
  ) async {
    final members = await _fetchMembers(stateCode, apiKey);
    return members
        .where((m) => (m.chamber).toLowerCase().contains('house'))
        .toList();
  }

  Future<List<CongressMember>> _fetchMembers(
    String stateCode,
    String apiKey,
  ) async {
    if (apiKey.trim().isEmpty) {
      throw const CongressApiException(
        'No Congress.gov API key set. Add one in Settings to refresh live data.',
      );
    }
    final uri = Uri.parse(
      '$_base/member/congress/current/${stateCode.toUpperCase()}'
      '?currentMember=true&limit=60&format=json&api_key=$apiKey',
    );
    try {
      final resp = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 15));
      if (resp.statusCode == 403) {
        throw const CongressApiException(
          'Congress.gov rejected the API key (403). Check the key in Settings.',
        );
      }
      if (resp.statusCode != 200) {
        throw CongressApiException(
          'Congress.gov request failed (${resp.statusCode}).',
        );
      }
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final list = (data['members'] as List?) ?? const [];
      return list
          .whereType<Map<String, dynamic>>()
          .map(CongressMember.fromJson)
          .toList();
    } on CongressApiException {
      rethrow;
    } catch (e) {
      debugPrint('Congress API error: $e');
      throw CongressApiException('Could not reach Congress.gov: $e');
    }
  }

  void dispose() => _client.close();
}

class CongressMember {
  const CongressMember({
    required this.name,
    required this.chamber,
    this.district,
    this.party,
  });

  final String name;
  final String chamber;
  final String? district;
  final String? party;

  factory CongressMember.fromJson(Map<String, dynamic> json) {
    // The v3 API nests the current chamber under `terms.item`.
    String chamber = '';
    final terms = json['terms'];
    if (terms is Map &&
        terms['item'] is List &&
        (terms['item'] as List).isNotEmpty) {
      final last = (terms['item'] as List).last;
      if (last is Map && last['chamber'] != null) {
        chamber = last['chamber'].toString();
      }
    }
    return CongressMember(
      name: (json['name'] ?? '').toString(),
      chamber: chamber,
      district: json['district']?.toString(),
      party: json['partyName']?.toString(),
    );
  }
}

class CongressApiException implements Exception {
  const CongressApiException(this.message);
  final String message;
  @override
  String toString() => message;
}
