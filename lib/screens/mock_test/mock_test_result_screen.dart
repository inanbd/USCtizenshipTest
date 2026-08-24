import 'package:flutter/material.dart';

import '../../models/enums.dart';
import '../../models/test_result.dart';

class MockTestResultScreen extends StatelessWidget {
  const MockTestResultScreen({super.key, required this.result});

  final TestResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final passed = result.passed;
    final color = passed ? theme.colorScheme.primary : theme.colorScheme.secondary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Results'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Card(
                    color: color.withValues(alpha: 0.12),
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Icon(
                            passed
                                ? Icons.emoji_events_rounded
                                : Icons.replay_rounded,
                            size: 56,
                            color: color,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            passed ? 'You passed!' : 'Keep practicing',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: color,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${result.correctCount} of ${result.total} correct '
                            '· ${(result.score * 100).round()}%',
                            style: theme.textTheme.titleMedium,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Passing score: ${result.version.passCount}/'
                            '${result.version.askedCount}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text('Review',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  ...result.answers.map((a) => _AnswerReviewTile(answer: a)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => Navigator.of(context).popUntil(
                        (r) => r.isFirst,
                      ),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnswerReviewTile extends StatelessWidget {
  const _AnswerReviewTile({required this.answer});
  final AnsweredQuestion answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color =
        answer.correct ? theme.colorScheme.primary : theme.colorScheme.error;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  answer.correct
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(answer.prompt,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (answer.userAnswer.isNotEmpty)
              _line(context, 'You', answer.userAnswer,
                  theme.colorScheme.onSurfaceVariant),
            _line(context, 'Answer', answer.acceptedAnswers.join(', '),
                theme.colorScheme.primary),
          ],
        ),
      ),
    );
  }

  Widget _line(BuildContext context, String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    )),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
