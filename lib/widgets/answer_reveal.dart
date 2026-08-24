import 'package:flutter/material.dart';

import '../models/question.dart';

/// Shows the accepted answer(s) for a question, plus any USCIS note and flags
/// for state-dependent / time-sensitive answers.
class AnswerReveal extends StatelessWidget {
  const AnswerReveal({
    super.key,
    required this.question,
    required this.acceptedAnswers,
    this.unresolved = false,
  });

  final Question question;
  final List<String> acceptedAnswers;

  /// True when a state-dependent answer hasn't been provided by the user yet.
  final bool unresolved;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (question.requiredCount > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              'Give ${question.requiredCount} answers:',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
        if (unresolved)
          _InfoBanner(
            icon: Icons.info_outline_rounded,
            color: scheme.tertiary,
            text: question.isStateDependent
                ? 'This answer depends on your state. Set it in “My State Info”.'
                : 'Set this answer in Settings.',
          )
        else
          ...acceptedAnswers.map(
            (a) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_rounded,
                      size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(a, style: theme.textTheme.bodyLarge),
                  ),
                ],
              ),
            ),
          ),
        if (question.note != null) ...[
          const SizedBox(height: 8),
          _InfoBanner(
            icon: Icons.lightbulb_outline_rounded,
            color: scheme.secondary,
            text: question.note!,
          ),
        ],
        if (question.isTimeSensitive)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _InfoBanner(
              icon: Icons.update_rounded,
              color: scheme.tertiary,
              text:
                  'This answer changes over time. Update it in Settings › Current officials.',
            ),
          ),
      ],
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
