import '../data/question_repository.dart';
import '../models/enums.dart';
import '../models/study_plan.dart';

/// Builds a dated study plan that spreads all of a test's questions across the
/// days remaining until the exam, inserting periodic review days.
class StudyPlanGenerator {
  const StudyPlanGenerator._();

  /// [testDate] is the target exam date. [seniorOnly] restricts the plan to the
  /// 20 asterisked (65/20) questions.
  static StudyPlan generate({
    required TestVersion version,
    required DateTime testDate,
    bool seniorOnly = false,
    DateTime? from,
  }) {
    final today = _dateOnly(from ?? DateTime.now());
    final target = _dateOnly(testDate);

    var totalDays = target.difference(today).inDays + 1; // include today
    if (totalDays < 1) totalDays = 1;

    final questions = seniorOnly
        ? QuestionRepository.senior(version)
        : QuestionRepository.forVersion(version);
    final ids = questions.map((q) => q.id).toList();

    final days = <StudyDay>[];

    if (totalDays == 1) {
      days.add(
        StudyDay(
          dayNumber: 1,
          date: today,
          questionIds: ids,
          isReviewDay: true,
        ),
      );
      return StudyPlan(
        version: version,
        createdAt: DateTime.now(),
        testDate: target,
        days: days,
        completedDayNumbers: {},
      );
    }

    // Every 4th day and the final day are review days.
    bool isReview(int dayNumber) =>
        dayNumber != 1 && (dayNumber % 4 == 0 || dayNumber == totalDays);

    final learningDayNumbers = <int>[];
    for (var d = 1; d <= totalDays; d++) {
      if (!isReview(d)) learningDayNumbers.add(d);
    }

    final chunks = _distribute(ids, learningDayNumbers.length);
    final chunkByDay = <int, List<int>>{};
    for (var i = 0; i < learningDayNumbers.length; i++) {
      chunkByDay[learningDayNumbers[i]] = chunks[i];
    }

    final learnedSoFar = <int>[];
    for (var d = 1; d <= totalDays; d++) {
      final date = today.add(Duration(days: d - 1));
      final chunk = chunkByDay[d] ?? const [];
      if (isReview(d) || chunk.isEmpty) {
        days.add(
          StudyDay(
            dayNumber: d,
            date: date,
            questionIds: List<int>.from(learnedSoFar),
            isReviewDay: true,
          ),
        );
      } else {
        learnedSoFar.addAll(chunk);
        days.add(
          StudyDay(
            dayNumber: d,
            date: date,
            questionIds: chunk,
            isReviewDay: false,
          ),
        );
      }
    }

    return StudyPlan(
      version: version,
      createdAt: DateTime.now(),
      testDate: target,
      days: days,
      completedDayNumbers: {},
    );
  }

  /// Splits [ids] into [buckets] near-equal contiguous chunks (front-loaded).
  static List<List<int>> _distribute(List<int> ids, int buckets) {
    if (buckets <= 0) return [ids];
    final result = List.generate(buckets, (_) => <int>[]);
    if (ids.isEmpty) return result;
    final base = ids.length ~/ buckets;
    final remainder = ids.length % buckets;
    var index = 0;
    for (var b = 0; b < buckets; b++) {
      final take = base + (b < remainder ? 1 : 0);
      for (var i = 0; i < take && index < ids.length; i++) {
        result[b].add(ids[index++]);
      }
    }
    return result;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
}
