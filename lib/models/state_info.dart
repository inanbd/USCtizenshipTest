/// The applicant's state-specific civics answers.
///
/// The state capital comes from bundled static data. The person-name fields
/// (governor, senators, representative) change over time, so they are entered
/// by the user or refreshed from a public API (see CongressApiService).
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
  });

  /// Two-letter USPS code, e.g. "CA". "DC" for the District of Columbia.
  final String code;
  final String name;
  final String capital;

  final String? governor;
  final List<String> senators;
  final String? representative;

  final DateTime? updatedAt;
  final StateDataSource source;

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
    );
  }

  Map<String, dynamic> toJson() => {
        'code': code,
        'name': name,
        'capital': capital,
        'governor': governor,
        'senators': senators,
        'representative': representative,
        'updatedAt': updatedAt?.toIso8601String(),
        'source': source.name,
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
    );
  }
}

enum StateDataSource { bundled, manual, api }
