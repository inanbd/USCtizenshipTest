import 'state_answers.dart';

/// The applicant's state-specific civics answers.
///
/// The state capital comes from bundled static data, so it works offline. The
/// person-name fields (governor, senators, representative) change over time, so
/// they are pulled from the backend (see StateAnswersService) or typed by hand.
/// Anything typed by hand is remembered in [manualFields] and survives a
/// refresh.
class StateInfo {
  const StateInfo({
    required this.code,
    required this.name,
    required this.capital,
    this.governor,
    this.senators = const [],
    this.representative,
    this.updatedAt,
    this.source = StateDataSource.bundled,
    this.manualFields = const {},
  });

  /// Keys used in [manualFields].
  static const fieldGovernor = 'governor';
  static const fieldSenators = 'senators';
  static const fieldRepresentative = 'representative';

  /// Two-letter USPS code, e.g. "CA". "DC" for the District of Columbia.
  final String code;
  final String name;
  final String capital;

  final String? governor;
  final List<String> senators;
  final String? representative;

  final DateTime? updatedAt;
  final StateDataSource source;

  /// Which fields the user typed themselves. A refresh never overwrites these -
  /// the applicant knows their own district better than any national dataset.
  final Set<String> manualFields;

  bool get isDistrictOfColumbia => code == 'DC';

  bool get hasSenators => senators.any((s) => s.trim().isNotEmpty);
  bool get hasGovernor => (governor ?? '').trim().isNotEmpty;
  bool get hasRepresentative => (representative ?? '').trim().isNotEmpty;

  StateInfo copyWith({
    String? governor,
    List<String>? senators,
    String? representative,
    DateTime? updatedAt,
    StateDataSource? source,
    Set<String>? manualFields,
  }) {
    return StateInfo(
      code: code,
      name: name,
      capital: capital,
      governor: governor ?? this.governor,
      senators: senators ?? this.senators,
      representative: representative ?? this.representative,
      updatedAt: updatedAt ?? this.updatedAt,
      source: source ?? this.source,
      manualFields: manualFields ?? this.manualFields,
    );
  }

  /// Folds a backend payload in, leaving every field the user typed untouched.
  ///
  /// The representative is deliberately not filled from [answers]: the correct
  /// one depends on the applicant's congressional district, which only they
  /// know, so the UI has them pick from [StateAnswers.representatives].
  StateInfo applyFetched(StateAnswers answers) {
    final fetchedGovernor = answers.governor?.name.trim() ?? '';
    final fetchedSenators = [
      for (final s in answers.senatorNames)
        if (s.trim().isNotEmpty) s.trim(),
    ];

    final takeGovernor =
        !manualFields.contains(fieldGovernor) && fetchedGovernor.isNotEmpty;
    final takeSenators =
        !manualFields.contains(fieldSenators) && fetchedSenators.isNotEmpty;

    return copyWith(
      governor: takeGovernor ? fetchedGovernor : governor,
      senators: takeSenators ? fetchedSenators : senators,
      updatedAt: DateTime.now(),
      source: takeGovernor || takeSenators ? StateDataSource.api : source,
    );
  }

  /// Marks [field] as user-entered so later refreshes leave it alone.
  StateInfo markManual(String field) =>
      copyWith(manualFields: {...manualFields, field});

  /// Drops [field] back to whatever a refresh provides.
  StateInfo clearManual(String field) =>
      copyWith(manualFields: {...manualFields}..remove(field));

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'capital': capital,
    'governor': governor,
    'senators': senators,
    'representative': representative,
    'updatedAt': updatedAt?.toIso8601String(),
    'source': source.name,
    'manualFields': manualFields.toList()..sort(),
  };

  factory StateInfo.fromJson(Map<String, dynamic> json) {
    return StateInfo(
      code: json['code'] as String,
      name: json['name'] as String,
      capital: json['capital'] as String,
      governor: json['governor'] as String?,
      senators: (json['senators'] as List?)?.cast<String>() ?? const [],
      representative: json['representative'] as String?,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'] as String)
          : null,
      source: StateDataSource.values.firstWhere(
        (s) => s.name == json['source'],
        orElse: () => StateDataSource.bundled,
      ),
      manualFields: {
        for (final f in (json['manualFields'] as List?) ?? const [])
          f.toString(),
      },
    );
  }
}

enum StateDataSource { bundled, manual, api }
