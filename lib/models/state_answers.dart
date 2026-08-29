/// The state-dependent civics answers as the backend resolved them.
///
/// The backend owns this lookup so the app never needs a Congress.gov key of
/// its own, and so every surface (app, website) agrees on who represents you.
/// A fetched payload is cached on the device, which is what makes these answers
/// available on a plane the day before the interview.
class StateAnswers {
  const StateAnswers({
    required this.stateCode,
    required this.stateName,
    required this.capital,
    required this.isDistrictOfColumbia,
    this.governor,
    this.senators = const [],
    this.representatives = const [],
    this.congressAvailable = false,
    this.congressNotice,
    required this.fetchedAt,
  });

  final String stateCode;
  final String stateName;
  final String capital;
  final bool isDistrictOfColumbia;

  /// From the server's maintained table; null when the server has no row
  /// (D.C., or a state added after the last seed refresh).
  final GovernorAnswer? governor;

  final List<CongressMemberAnswer> senators;

  /// Every House member for the state. Only the applicant knows their district,
  /// so the UI has them pick one.
  final List<CongressMemberAnswer> representatives;

  /// False when the server has no Congress.gov key or could not reach it. The
  /// capital and governor are still usable; the rest is typed by hand.
  final bool congressAvailable;
  final String? congressNotice;

  /// When this app fetched the payload — shown so a stale cache is obvious.
  final DateTime fetchedAt;

  List<String> get senatorNames => [for (final s in senators) s.name];

  StateAnswers copyWith({
    List<CongressMemberAnswer>? senators,
    List<CongressMemberAnswer>? representatives,
    bool? congressAvailable,
    String? congressNotice,
  }) => StateAnswers(
    stateCode: stateCode,
    stateName: stateName,
    capital: capital,
    isDistrictOfColumbia: isDistrictOfColumbia,
    governor: governor,
    senators: senators ?? this.senators,
    representatives: representatives ?? this.representatives,
    congressAvailable: congressAvailable ?? this.congressAvailable,
    // Passing null clears the notice - a successful top-up has nothing to warn
    // about any more.
    congressNotice: congressNotice,
    fetchedAt: fetchedAt,
  );

  Map<String, dynamic> toJson() => {
    'stateCode': stateCode,
    'stateName': stateName,
    'capital': capital,
    'isDistrictOfColumbia': isDistrictOfColumbia,
    'governor': governor?.toJson(),
    'senators': [for (final s in senators) s.toJson()],
    'representatives': [for (final r in representatives) r.toJson()],
    'congressAvailable': congressAvailable,
    'congressNotice': congressNotice,
    'fetchedAt': fetchedAt.toIso8601String(),
  };

  /// Parses either the API response or a cached copy. The API omits
  /// `fetchedAt` (the server's own clock is not what the user cares about), so
  /// it falls back to now.
  factory StateAnswers.fromJson(Map<String, dynamic> json) {
    List<CongressMemberAnswer> members(String key) => [
      for (final m in (json[key] as List?) ?? const [])
        if (m is Map<String, dynamic>) CongressMemberAnswer.fromJson(m),
    ];

    final governor = json['governor'];
    return StateAnswers(
      stateCode: (json['stateCode'] ?? '').toString(),
      stateName: (json['stateName'] ?? '').toString(),
      capital: (json['capital'] ?? '').toString(),
      isDistrictOfColumbia: json['isDistrictOfColumbia'] == true,
      governor: governor is Map<String, dynamic>
          ? GovernorAnswer.fromJson(governor)
          : null,
      senators: members('senators'),
      representatives: members('representatives'),
      congressAvailable: json['congressAvailable'] == true,
      congressNotice: json['congressNotice'] as String?,
      fetchedAt:
          DateTime.tryParse((json['fetchedAt'] ?? '').toString()) ??
          DateTime.now(),
    );
  }
}

/// A governor, with the date the server's table was last verified.
class GovernorAnswer {
  const GovernorAnswer({
    required this.name,
    this.since,
    this.asOf,
    this.source,
  });

  final String name;

  /// When they took office, when known.
  final DateTime? since;

  /// When the server's table was last checked — the number that tells a user
  /// whether to trust this or look it up.
  final DateTime? asOf;
  final String? source;

  Map<String, dynamic> toJson() => {
    'name': name,
    'since': since?.toIso8601String(),
    'asOf': asOf?.toIso8601String(),
    'source': source,
  };

  factory GovernorAnswer.fromJson(Map<String, dynamic> json) => GovernorAnswer(
    name: (json['name'] ?? '').toString(),
    since: DateTime.tryParse((json['since'] ?? '').toString()),
    asOf: DateTime.tryParse((json['asOf'] ?? '').toString()),
    source: json['source'] as String?,
  );
}

class CongressMemberAnswer {
  const CongressMemberAnswer({
    required this.name,
    this.chamber = '',
    this.district,
    this.party,
  });

  final String name;
  final String chamber;
  final String? district;
  final String? party;

  /// "Jane Doe — District 3 (Democratic)", for the representative picker.
  String get label {
    final parts = <String>[];
    if ((district ?? '').isNotEmpty) parts.add('District $district');
    if ((party ?? '').isNotEmpty) parts.add(party!);
    return parts.isEmpty ? name : '$name — ${parts.join(' · ')}';
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'chamber': chamber,
    'district': district,
    'party': party,
  };

  factory CongressMemberAnswer.fromJson(Map<String, dynamic> json) =>
      CongressMemberAnswer(
        name: (json['name'] ?? '').toString(),
        chamber: (json['chamber'] ?? '').toString(),
        district: json['district']?.toString(),
        party: json['party'] as String?,
      );
}
