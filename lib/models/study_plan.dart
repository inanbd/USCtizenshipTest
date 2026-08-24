import 'enums.dart';

/// A single day's assignment in a study plan.
class StudyDay {
  const StudyDay({
    required this.dayNumber,
    required this.date,
    required this.questionIds,
    required this.isReviewDay,
  });

  final int dayNumber;
  final DateTime date;

  /// Question ids (within the plan's [StudyPlan.version]) to learn/review today.
  final List<int> questionIds;

  /// Review days re-cover previously assigned questions rather than new ones.
  final bool isReviewDay;

  Map<String, dynamic> toJson() => {
    'dayNumber': dayNumber,
    'date': date.toIso8601String(),
    'questionIds': questionIds,
    'isReviewDay': isReviewDay,
  };

  factory StudyDay.fromJson(Map<String, dynamic> json) => StudyDay(
    dayNumber: json['dayNumber'] as int,
    date: DateTime.parse(json['date'] as String),
    questionIds: (json['questionIds'] as List).cast<int>(),
    isReviewDay: json['isReviewDay'] as bool,
  );
}

/// A dated plan that spreads all questions across the days until the test,
/// with periodic review days.
class StudyPlan {
  const StudyPlan({
    required this.version,
    required this.createdAt,
    required this.testDate,
    required this.days,
    required this.completedDayNumbers,
  });

  final TestVersion version;
  final DateTime createdAt;
  final DateTime testDate;
  final List<StudyDay> days;
  final Set<int> completedDayNumbers;

  int get totalDays => days.length;
  int get completedCount => completedDayNumbers.length;
  double get progress => totalDays == 0 ? 0 : completedCount / totalDays;

  StudyPlan copyWith({Set<int>? completedDayNumbers}) => StudyPlan(
    version: version,
    createdAt: createdAt,
    testDate: testDate,
    days: days,
    completedDayNumbers: completedDayNumbers ?? this.completedDayNumbers,
  );

  Map<String, dynamic> toJson() => {
    'version': version.storageKey,
    'createdAt': createdAt.toIso8601String(),
    'testDate': testDate.toIso8601String(),
    'days': days.map((d) => d.toJson()).toList(),
    'completedDayNumbers': completedDayNumbers.toList(),
  };

  factory StudyPlan.fromJson(Map<String, dynamic> json) => StudyPlan(
    version: json['version'] == 'v2020' ? TestVersion.v2020 : TestVersion.v2008,
    createdAt: DateTime.parse(json['createdAt'] as String),
    testDate: DateTime.parse(json['testDate'] as String),
    days: (json['days'] as List)
        .map((d) => StudyDay.fromJson(d as Map<String, dynamic>))
        .toList(),
    completedDayNumbers: (json['completedDayNumbers'] as List)
        .cast<int>()
        .toSet(),
  );
}
