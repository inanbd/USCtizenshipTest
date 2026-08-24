import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/question_repository.dart';
import '../models/enums.dart';
import '../providers/progress_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/study_plan_provider.dart';
import 'browse/browse_screen.dart';
import 'flashcards/flashcards_screen.dart';
import 'mock_test/mock_test_setup_screen.dart';
import 'settings/settings_screen.dart';
import 'study_plan/study_plan_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final progress = context.watch<ProgressProvider>();
    final version = settings.testVersion;
    final total = QuestionRepository.forVersion(version).length;
    final learned = progress.learnedCount(version);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Civics Prep'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            tooltip: 'Settings',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Text(
              'U.S. Citizenship Test',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Learn, drill, and take mock civics tests.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            const SizedBox(height: 16),
            _VersionSelector(version: version),
            const SizedBox(height: 16),
            _ProgressCard(version: version, learned: learned, total: total),
            const SizedBox(height: 16),
            const _TodayPlanCard(),
            const SizedBox(height: 16),
            Text('Practice',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )),
            const SizedBox(height: 8),
            _FeatureTile(
              icon: Icons.quiz_rounded,
              title: 'Mock Test',
              subtitle:
                  'See & hear questions, write or speak your answers. ${version.askedCount} questions, pass with ${version.passCount}.',
              color: Theme.of(context).colorScheme.primary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const MockTestSetupScreen(),
              )),
            ),
            _FeatureTile(
              icon: Icons.style_rounded,
              title: 'Flashcards',
              subtitle: 'Flip through all $total questions with audio.',
              color: Theme.of(context).colorScheme.secondary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const FlashcardsScreen(),
              )),
            ),
            _FeatureTile(
              icon: Icons.event_note_rounded,
              title: 'Study Plan',
              subtitle: 'Get a day-by-day plan based on your test date.',
              color: Theme.of(context).colorScheme.tertiary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const StudyPlanScreen(),
              )),
            ),
            _FeatureTile(
              icon: Icons.menu_book_rounded,
              title: 'Browse Questions',
              subtitle: 'All questions by topic, with answers and audio.',
              color: Theme.of(context).colorScheme.primary,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const BrowseScreen(),
              )),
            ),
          ],
        ),
      ),
    );
  }
}

class _VersionSelector extends StatelessWidget {
  const _VersionSelector({required this.version});
  final TestVersion version;

  @override
  Widget build(BuildContext context) {
    final settings = context.read<SettingsProvider>();
    return SegmentedButton<TestVersion>(
      segments: const [
        ButtonSegment(
          value: TestVersion.v2008,
          label: Text('2008 · 100Q'),
          icon: Icon(Icons.history_edu_rounded),
        ),
        ButtonSegment(
          value: TestVersion.v2020,
          label: Text('2020 · 128Q'),
          icon: Icon(Icons.new_releases_rounded),
        ),
      ],
      selected: {version},
      onSelectionChanged: (s) => settings.setTestVersion(s.first),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.version,
    required this.learned,
    required this.total,
  });

  final TestVersion version;
  final int learned;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = context.watch<ProgressProvider>();
    final last = progress.historyFor(version).isNotEmpty
        ? progress.historyFor(version).first
        : null;
    final pct = total == 0 ? 0.0 : learned / total;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Your progress',
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(version.shortLabel,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    )),
              ],
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: pct,
                minHeight: 10,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 8),
            Text('$learned of $total marked known',
                style: theme.textTheme.bodyMedium),
            if (last != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  Icon(
                    last.passed
                        ? Icons.emoji_events_rounded
                        : Icons.trending_up_rounded,
                    color: last.passed
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Last mock test: ${last.correctCount}/${last.total} '
                      '(${last.passed ? "Passed" : "Keep practicing"})',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TodayPlanCard extends StatelessWidget {
  const _TodayPlanCard();

  @override
  Widget build(BuildContext context) {
    final planProvider = context.watch<StudyPlanProvider>();
    final plan = planProvider.plan;
    if (plan == null) return const SizedBox.shrink();
    final today = planProvider.todayDay;
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.primaryContainer,
      child: InkWell(
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => const StudyPlanScreen(),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.today_rounded,
                  color: theme.colorScheme.onPrimaryContainer),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      today == null
                          ? 'Study plan active'
                          : 'Today: ${today.isReviewDay ? "Review" : "${today.questionIds.length} new questions"}',
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${(plan.progress * 100).round()}% complete · '
                      '${plan.days.length}-day plan',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer
                            .withValues(alpha: 0.8),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded,
                  color: theme.colorScheme.onPrimaryContainer),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        )),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}
