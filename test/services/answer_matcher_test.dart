import 'package:citizenship_test/services/answer_matcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('basic matching', () {
    test('accepts the exact answer regardless of case and punctuation', () {
      expect(
        AnswerMatcher.isCorrect('the constitution', ['the Constitution']),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('Constitution!', ['the Constitution']),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('  CONSTITUTION  ', ['the Constitution']),
        isTrue,
      );
    });

    test('accepts any one of several accepted answers', () {
      const rights = ['speech', 'religion', 'assembly', 'press'];
      for (final r in rights) {
        expect(AnswerMatcher.isCorrect(r, rights), isTrue);
      }
    });

    test('rejects a wrong answer', () {
      expect(
        AnswerMatcher.isCorrect('the Declaration', ['the Constitution']),
        isFalse,
      );
      expect(AnswerMatcher.isCorrect('Canada', ['Mexico']), isFalse);
    });

    test('rejects empty or content-free input', () {
      expect(AnswerMatcher.isCorrect('', ['the Constitution']), isFalse);
      expect(AnswerMatcher.isCorrect('   ', ['the Constitution']), isFalse);
      expect(
        AnswerMatcher.isCorrect('the of and', ['the Constitution']),
        isFalse,
      );
    });

    test('handles an empty accepted-answer list', () {
      expect(AnswerMatcher.isCorrect('anything', const []), isFalse);
    });
  });

  group('parenthetical hints', () {
    test('matches with or without the parenthetical part', () {
      expect(AnswerMatcher.isCorrect('Madison', ['(James) Madison']), isTrue);
      expect(
        AnswerMatcher.isCorrect('James Madison', ['(James) Madison']),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('Jefferson', ['(Thomas) Jefferson']),
        isTrue,
      );
    });

    test('matches numeric answers written either way', () {
      expect(AnswerMatcher.isCorrect('27', ['twenty-seven (27)']), isTrue);
      expect(
        AnswerMatcher.isCorrect('twenty seven', ['twenty-seven (27)']),
        isTrue,
      );
      expect(AnswerMatcher.isCorrect('100', ['one hundred (100)']), isTrue);
    });
  });

  group('lenient phrasing', () {
    test('accepts a longer phrase containing the answer', () {
      expect(
        AnswerMatcher.isCorrect('it is the president', ['the President']),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('the President of the United States', [
          'the President',
        ]),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('I think it is Washington', [
          '(George) Washington',
        ]),
        isTrue,
      );
    });

    test('accepts a shorter phrase drawn from the answer', () {
      expect(
        AnswerMatcher.isCorrect('the Speaker', ['the Speaker of the House']),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('18 and older', [
          'Citizens eighteen (18) and older (can vote).',
        ]),
        isTrue,
      );
    });

    test('tolerates typos and speech-recognition slips', () {
      expect(
        AnswerMatcher.isCorrect('washinton', ['(George) Washington']),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('constitucion', ['the Constitution']),
        isTrue,
      );
    });

    test('does not fuzzy-match genuinely different short words', () {
      expect(AnswerMatcher.isCorrect('war', ['bar']), isFalse);
      expect(AnswerMatcher.isCorrect('Ohio', ['Iowa']), isFalse);
    });
  });

  group('modifiers must agree', () {
    test('does not accept "Vice President" for "the President"', () {
      expect(
        AnswerMatcher.isCorrect('the Vice President', ['the President']),
        isFalse,
      );
    });

    test('does not accept "the President" for "the Vice President"', () {
      expect(
        AnswerMatcher.isCorrect('the President', ['the Vice President']),
        isFalse,
      );
    });

    test('still accepts the correct one of the pair', () {
      expect(
        AnswerMatcher.isCorrect('vice president', ['the Vice President']),
        isTrue,
      );
      expect(AnswerMatcher.isCorrect('president', ['the President']), isTrue);
    });

    test('rejects a negated answer', () {
      expect(
        AnswerMatcher.isCorrect('not the Constitution', ['the Constitution']),
        isFalse,
      );
      expect(
        AnswerMatcher.isCorrect('it is never the president', ['the President']),
        isFalse,
      );
    });
  });

  group('multi-answer questions', () {
    const parties = ['Democratic', 'Republican'];

    test('requires the full number of distinct answers', () {
      expect(
        AnswerMatcher.isCorrect('Democratic', parties, requiredCount: 2),
        isFalse,
      );
      expect(
        AnswerMatcher.isCorrect(
          'Democratic and Republican',
          parties,
          requiredCount: 2,
        ),
        isTrue,
      );
    });

    test('accepts answers separated by commas or slashes, in any order', () {
      expect(
        AnswerMatcher.isCorrect(
          'republican, democratic',
          parties,
          requiredCount: 2,
        ),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect(
          'republican/democratic',
          parties,
          requiredCount: 2,
        ),
        isTrue,
      );
    });

    test('one vague word cannot stand in for several answers', () {
      const freedoms = [
        'freedom of expression',
        'freedom of speech',
        'freedom of assembly',
        'freedom to petition the government',
        'freedom of religion',
        'the right to bear arms',
      ];
      final result = AnswerMatcher.evaluate(
        'freedom',
        freedoms,
        requiredCount: 2,
      );
      expect(
        result.matchedAnswers.length,
        1,
        reason: '"freedom" should credit at most one right',
      );
      expect(result.correct, isFalse);
    });

    test('the same answer is never credited twice', () {
      final result = AnswerMatcher.evaluate(
        'Democratic, Democratic',
        parties,
        requiredCount: 2,
      );
      expect(result.matchedAnswers, ['Democratic']);
      expect(result.correct, isFalse);
    });

    test('handles a three-answer question', () {
      const states = [
        'New Hampshire',
        'Massachusetts',
        'Rhode Island',
        'Connecticut',
        'New York',
      ];
      expect(
        AnswerMatcher.isCorrect(
          'New York, Massachusetts, Connecticut',
          states,
          requiredCount: 3,
        ),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect(
          'New York, Massachusetts',
          states,
          requiredCount: 3,
        ),
        isFalse,
      );
    });

    test('handles a five-answer question', () {
      const states = [
        'New Hampshire',
        'Massachusetts',
        'Rhode Island',
        'Connecticut',
        'New York',
        'New Jersey',
        'Pennsylvania',
        'Delaware',
        'Georgia',
      ];
      expect(
        AnswerMatcher.isCorrect(
          'Georgia, Delaware, Pennsylvania, New Jersey, New York',
          states,
          requiredCount: 5,
        ),
        isTrue,
      );
    });

    test('distinguishes the two houses of Congress', () {
      const parts = ['the Senate', 'the House of Representatives'];
      expect(
        AnswerMatcher.isCorrect('senate and house', parts, requiredCount: 2),
        isTrue,
      );
      expect(
        AnswerMatcher.isCorrect('senate', parts, requiredCount: 2),
        isFalse,
      );
    });

    test('distinguishes two cabinet positions', () {
      const cabinet = [
        'Secretary of State',
        'Secretary of Defense',
        'Secretary of Labor',
      ];
      final result = AnswerMatcher.evaluate(
        'Secretary of State and Secretary of Defense',
        cabinet,
        requiredCount: 2,
      );
      expect(result.correct, isTrue);
      expect(
        result.matchedAnswers,
        containsAll(['Secretary of State', 'Secretary of Defense']),
      );
    });
  });

  group('evaluate reports what matched', () {
    test('lists the accepted answers the user covered', () {
      final result = AnswerMatcher.evaluate('life and liberty', [
        'life',
        'liberty',
        'pursuit of happiness',
      ], requiredCount: 2);
      expect(result.correct, isTrue);
      expect(result.matchedAnswers, ['life', 'liberty']);
    });

    test('returns no matches for a wrong answer', () {
      final result = AnswerMatcher.evaluate('bananas', ['life', 'liberty']);
      expect(result.correct, isFalse);
      expect(result.matchedAnswers, isEmpty);
    });
  });
}
