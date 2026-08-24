import 'package:citizenship_test/data/question_repository.dart';
import 'package:citizenship_test/models/enums.dart';
import 'package:citizenship_test/services/study_plan_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('StudyPlanGenerator', () {
    test('covers every question across the days', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: DateTime.now().add(const Duration(days: 20)),
      );
      final learned = <int>{};
      for (final day in plan.days.where((d) => !d.isReviewDay)) {
        learned.addAll(day.questionIds);
      }
      final total = QuestionRepository.forVersion(TestVersion.v2008).length;
      expect(learned.length, total);
    });

    test('produces one cram day when the test is today', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2020,
        testDate: DateTime.now(),
      );
      expect(plan.days.length, 1);
      expect(plan.days.first.questionIds.length,
          QuestionRepository.forVersion(TestVersion.v2020).length);
    });

    test('includes review days for longer plans', () {
      final plan = StudyPlanGenerator.generate(
        version: TestVersion.v2008,
        testDate: DateTime.now().add(const Duration(days: 12)),
      );
      expect(plan.days.any((d) => d.isReviewDay), isTrue);
    });
  });

  group('datasets', () {
    test('2008 has 100 questions with unique ids', () {
      final q = QuestionRepository.forVersion(TestVersion.v2008);
      expect(q.length, 100);
      expect(q.map((e) => e.id).toSet().length, 100);
    });

    test('2020 has 128 questions with unique ids', () {
      final q = QuestionRepository.forVersion(TestVersion.v2020);
      expect(q.length, 128);
      expect(q.map((e) => e.id).toSet().length, 128);
    });

    test('each version has 20 senior (65/20) questions', () {
      expect(QuestionRepository.senior(TestVersion.v2008).length, 20);
      expect(QuestionRepository.senior(TestVersion.v2020).length, 20);
    });
  });
}
