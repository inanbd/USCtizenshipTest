import 'package:citizenship_test/data/question_repository.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/services/study_plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
  final today = dateOnly(DateTime.now());

  group('coverage', () {
    test('teaches every question exactly once across the learning days', () {
      for (final version in TestVersion.values) {
        final plan = StudyPlanGenerator.generate(
          version: version,
          testDate: today.add(const Duration(days: 20)),
        );
        final taught = <int>[];
        for (final day in plan.days.where((d) => !d.isReviewDay)) {
          taught.addAll(day.questionIds);
        }
        final expected = QuestionRepository.forVersion(version)
            .map((q) => q.id)
            .toList();
        expect(
          taught.toSet().length,
          taught.length,
          reason: '${version.shortLabel}: no question taught twice',
        );
        expect(
          taught.toSet(),
          expected.toSet(),
          reason: '${version.shortLabel}: every question covered',
        );
      }
    });

    test('covers only the 20 starred questions in 65/20 mode', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2020,
        testDate: today.add(const Duration(days: 10)),
        seniorOnly: true,
      );
      final taught = <int>{};
      for (final day in plan.days.where((d) => !d.isReviewDay)) {
        taught.addAll(day.questionIds);
      }
      expect(taught.length, 20);
      final seniorIds = QuestionRepository.senior(TestVersion.v2020)
          .map((q) => q.id)
          .toSet();
      expect(taught, seniorIds);
    });
  });

  group('schedule shape', () {
    test('runs from today through the test date inclusive', () {
      final testDate = today.add(const Duration(days: 9));
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: testDate,
      );
      expect(plan.days.length, 10);
      expect(dateOnly(plan.days.first.date), today);
      expect(dateOnly(plan.days.last.date), testDate);
      expect(plan.testDate, testDate);
    });

    test('numbers days consecutively from 1 with consecutive dates', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: today.add(const Duration(days: 7)),
      );
      for (var i = 0; i < plan.days.length; i++) {
        expect(plan.days[i].dayNumber, i + 1);
        expect(dateOnly(plan.days[i].date), today.add(Duration(days: i)));
      }
    });

    test('includes review days and never makes day 1 a review day', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: today.add(const Duration(days: 11)),
      );
      expect(plan.days.any((d) => d.isReviewDay), isTrue);
      expect(plan.days.first.isReviewDay, isFalse);
    });

    test('ends on a review day covering everything learned', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: today.add(const Duration(days: 14)),
      );
      final last = plan.days.last;
      expect(last.isReviewDay, isTrue);
      expect(
        last.questionIds.length,
        QuestionRepository.forVersion(TestVersion.v2008).length,
      );
    });

    test('review days only revisit questions already taught', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: today.add(const Duration(days: 16)),
      );
      final taughtSoFar = <int>{};
      for (final day in plan.days) {
        if (day.isReviewDay) {
          expect(
            taughtSoFar.containsAll(day.questionIds),
            isTrue,
            reason: 'day ${day.dayNumber} reviews unseen questions',
          );
        } else {
          taughtSoFar.addAll(day.questionIds);
        }
      }
    });

    test('spreads questions evenly across learning days', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2020,
        testDate: today.add(const Duration(days: 30)),
      );
      final loads = plan.days
          .where((d) => !d.isReviewDay)
          .map((d) => d.questionIds.length)
          .toList();
      expect(loads, isNotEmpty);
      final min = loads.reduce((a, b) => a < b ? a : b);
      final max = loads.reduce((a, b) => a > b ? a : b);
      expect(
        max - min,
        lessThanOrEqualTo(1),
        reason: 'daily load should differ by at most one question',
      );
    });
  });

  group('edge cases', () {
    test('a test today produces a single cram day with everything', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2020,
        testDate: DateTime.now(),
      );
      expect(plan.days.length, 1);
      expect(plan.days.single.isReviewDay, isTrue);
      expect(plan.days.single.questionIds.length, 128);
    });

    test('a past test date still yields a usable one-day plan', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: today.subtract(const Duration(days: 5)),
      );
      expect(plan.days.length, 1);
      expect(plan.days.single.questionIds.length, 100);
    });

    test(
      'a very long runway still covers everything without empty new days',
      () {
        final plan = StudyPlanGenerator.generate(
          version: TestVersion.v2008,
          testDate: today.add(const Duration(days: 300)),
        );
        for (final day in plan.days.where((d) => !d.isReviewDay)) {
          expect(
            day.questionIds,
            isNotEmpty,
            reason: 'day ${day.dayNumber} should not be an empty learning day',
          );
        }
        final taught = <int>{};
        for (final d in plan.days.where((d) => !d.isReviewDay)) {
          taught.addAll(d.questionIds);
        }
        expect(taught.length, 100);
      },
    );

    test('starts with no days completed', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: today.add(const Duration(days: 5)),
      );
      expect(plan.completedDayNumbers, isEmpty);
      expect(plan.progress, 0);
    });
  });
}
