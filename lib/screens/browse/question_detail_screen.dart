import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/enums.dart';
import '../../models/question.dart';
import '../../providers/progress_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/answer_reveal.dart';
import '../../widgets/speaker_button.dart';

/// Shows a single question with audio, a tap-to-reveal answer, and controls to
/// mark it known or favorite.
class QuestionDetailScreen extends StatefulWidget {
  const QuestionDetailScreen({super.key, required this.question});

  final Question question;

  @override
  State<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends State<QuestionDetailScreen> {
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final q = widget.question;
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final progress = context.watch<ProgressProvider>();

    final accepted = QuestionRepository.effectiveAnswers(
      q,
      state: settings.stateInfo,
      officials: settings.officials,
    );
    final unresolved = QuestionRepository.needsUserData(
      q,
      state: settings.stateInfo,
      officials: settings.officials,
    );
    final isKnown = progress.isLearned(q.version, q.id);
    final isFav = progress.isFavorite(q.version, q.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${q.id}'),
        actions: [
          IconButton(
            tooltip: isFav ? 'Unstar' : 'Star for practice',
            icon: Icon(isFav ? Icons.star_rounded : Icons.star_border_rounded),
            onPressed: () => progress.toggleFavorite(q.version, q.id),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Tag(text: q.category.label),
                _Tag(text: q.section),
                if (q.senior)
                  _Tag(text: '65/20', color: theme.colorScheme.tertiary),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              q.prompt,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                SpeakerButton(text: q.prompt),
                const SizedBox(width: 12),
                if (_revealed)
                  SpeakerButton(
                    text: accepted.isEmpty ? q.answers.first : accepted.first,
                    label: 'Hear answer',
                  ),
              ],
            ),
            const SizedBox(height: 24),
            if (!_revealed)
              FilledButton.tonalIcon(
                onPressed: () => setState(() => _revealed = true),
                icon: const Icon(Icons.visibility_rounded),
                label: const Text('Show answer'),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: AnswerReveal(
                    question: q,
                    acceptedAnswers: accepted.isEmpty ? q.answers : accepted,
                    unresolved: unresolved,
                  ),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: isKnown
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                foregroundColor: isKnown
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurface,
              ),
              onPressed: () => progress.toggleLearned(q.version, q.id),
              icon: Icon(
                isKnown ? Icons.check_circle_rounded : Icons.circle_outlined,
              ),
              label: Text(isKnown ? 'Marked as known' : 'Mark as known'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, this.color});
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: c, fontWeight: FontWeight.w600),
      ),
    );
  }
}
