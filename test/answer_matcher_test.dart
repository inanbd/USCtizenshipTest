import 'package:citizenship_test/services/answer_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnswerMatcher', () {
    test('matches exact answer ignoring case and punctuation', () {
      expect(
        AnswerMatcher.isCorrect('the constitution', ['the Constitution']),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('Constitution!', ['the Constitution']),
        isTrue,
      );
    });

    test('handles parenthetical hints in accepted answers', () {
      expect(AnswerMatcher.isCorrect('Madison', ['(James) Madison']), isTrue);
      expect(
        AnswerMatcher.isCorrect('James Madison', ['(James) Madison']),
        isTrue,
      );
    });

    test('tolerates small typos / speech slips', () {
      expect(
        AnswerMatcher.isCorrect('washinton', ['(George) Washington']),
        isTrue,
      );
    });

    test('rejects wrong answers', () {
      expect(
        AnswerMatcher.isCorrect('the Declaration', ['the Constitution']),
        isFalse,
      );
    });

    test('accepts any one of several accepted answers', () {
      expect(
        AnswerMatcher.isCorrect('speech', [
          'speech',
          'religion',
          'assembly',
        ]),
        isTrue,
      );
    });

    test('requires the right number for name-two questions', () {
      const answers = ['Democratic', 'Republican'];
      expect(
        AnswerMatcher.isCorrect('Democratic', answers, requiredCount: 2),
        isFalse,
      );
      expect(
        AnswerMatcher.isCorrect(
          'Democratic and Republican',
          answers,
          requiredCount: 2,
        ),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect(
          'republican, democratic',
          answers,
          requiredCount: 2,
        ),
        isTrue,
      );
    });

    test('matches a longer phrase containing the accepted answer', () {
      expect(
        AnswerMatcher.isCorrect(
          'it is the president',
          ['the President'],
        ),
        isTrue,
      );
    });
  });
}
