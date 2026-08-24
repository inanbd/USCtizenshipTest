import 'enums.dart';

/// User-editable answers for the time-sensitive federal questions.
///
/// These change with elections/appointments. Defaults reflect the officials in
/// office as of the app's build date; USCIS directs applicants to verify the
/// current answers at uscis.gov/citizenship/testupdates, and the user can edit
/// them in Settings.
class Officials {
  const Officials({
    required this.president,
    required this.vicePresident,
    required this.speaker,
    required this.chiefJustice,
    required this.presidentParty,
    this.asOf,
  });

  final String president;
  final String vicePresident;
  final String speaker;
  final String chiefJustice;
  final String presidentParty;
  final DateTime? asOf;

  /// Defaults as of the build date (verify at uscis.gov/citizenship/testupdates).
  static final Officials defaults = Officials(
    president: 'Donald J. Trump',
    vicePresident: 'JD Vance',
    speaker: 'Mike Johnson',
    chiefJustice: 'John Roberts',
    presidentParty: 'Republican (Party)',
    asOf: DateTime(2025, 1, 20),
  );

  String forKind(AnswerKind kind) => switch (kind) {
    AnswerKind.president => president,
    AnswerKind.vicePresident => vicePresident,
    AnswerKind.speaker => speaker,
    AnswerKind.chiefJustice => chiefJustice,
    AnswerKind.presidentParty => presidentParty,
    _ => '',
  };

  Officials copyWith({
    String? president,
    String? vicePresident,
    String? speaker,
    String? chiefJustice,
    String? presidentParty,
    DateTime? asOf,
  }) => Officials(
    president: president ?? this.president,
    vicePresident: vicePresident ?? this.vicePresident,
    speaker: speaker ?? this.speaker,
    chiefJustice: chiefJustice ?? this.chiefJustice,
    presidentParty: presidentParty ?? this.presidentParty,
    asOf: asOf ?? this.asOf,
  );

  Map<String, dynamic> toJson() => {
    'president': president,
    'vicePresident': vicePresident,
    'speaker': speaker,
    'chiefJustice': chiefJustice,
    'presidentParty': presidentParty,
    'asOf': asOf?.toIso8601String(),
  };

  factory Officials.fromJson(Map<String, dynamic> json) => Officials(
    president: json['president'] as String? ?? defaults.president,
    vicePresident: json['vicePresident'] as String? ?? defaults.vicePresident,
    speaker: json['speaker'] as String? ?? defaults.speaker,
    chiefJustice: json['chiefJustice'] as String? ?? defaults.chiefJustice,
    presidentParty:
        json['presidentParty'] as String? ?? defaults.presidentParty,
    asOf: json['asOf'] != null
        ? DateTime.tryParse(json['asOf'] as String)
        : null,
  );
}
