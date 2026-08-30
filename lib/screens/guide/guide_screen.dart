import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/naturalization_guide.dart';
import '../../services/guide_service.dart';

/// The naturalization process end to end: what happens, when, how to apply and
/// what it costs. Reads offline from the bundled guide.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  NaturalizationGuide? _guide;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = context.read<GuideService>();
    try {
      // Show the bundled copy first so the screen is never empty, then take a
      // fresher one from the server if there is one — fees and timings change.
      final bundled = await service.current();
      if (!mounted) return;
      setState(() {
        _guide = bundled;
      });

      final fresher = await service.refresh();
      if (!mounted) return;
      setState(() {
        _guide = fresher;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final guide = _guide;
    if (guide == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('The Process')),
        body: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load the guide: $_error'),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('The Process'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Steps'),
              Tab(text: 'Apply & cost'),
              Tab(text: 'The tests'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              _StepsTab(guide: guide),
              _ApplyTab(guide: guide),
              _TestsTab(guide: guide),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepsTab extends StatelessWidget {
  const _StepsTab({required this.guide});
  final NaturalizationGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      key: const PageStorageKey('guide.steps'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        Card(
          color: theme.colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  guide.timeline.summary,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  guide.timeline.note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final (index, step) in guide.steps.indexed)
          _StepCard(step: step, number: index + 1),
        const SizedBox(height: 8),
        _SectionCard(title: 'Once you are sworn in', bullets: guide.afterOath),
        _SourcesCard(guide: guide),
      ],
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.number});

  final GuideStep step;
  final int number;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: theme.colorScheme.primary,
                  child: Text(
                    '$number',
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step.title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        step.timingDetail.isEmpty
                            ? step.timing
                            : '${step.timing} · ${step.timingDetail}',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(step.summary, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 8),
            for (final detail in step.details) _Bullet(text: detail),
          ],
        ),
      ),
    );
  }
}

class _ApplyTab extends StatelessWidget {
  const _ApplyTab({required this.guide});
  final NaturalizationGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligibility = guide.stepByKey('eligibility');

    return ListView(
      key: const PageStorageKey('guide.apply'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (eligibility != null)
          _SectionCard(
            title: eligibility.title,
            subtitle: eligibility.summary,
            bullets: eligibility.details,
          ),
        Text(
          'Two ways to file',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final method in guide.applying.methods)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          method.name,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Chip(
                        label: Text(method.fee),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(method.summary, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 8),
                  for (final point in method.points) _Bullet(text: point),
                ],
              ),
            ),
          ),
        _SectionCard(
          title: 'Have these ready before you start',
          bullets: guide.applying.checklist,
        ),
        Text(
          'What it costs',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              children: [
                for (final cost in guide.costs.items)
                  ListTile(
                    dense: true,
                    title: Text(cost.label),
                    subtitle: Text(
                      cost.note == null
                          ? cost.when
                          : '${cost.when} · ${cost.note}',
                    ),
                    isThreeLine: cost.note != null,
                    trailing: Text(
                      cost.amount,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(title: 'Worth knowing', bullets: guide.costs.notes),
        if (guide.costs.proposedChange case final proposed?)
          Card(
            color: theme.colorScheme.tertiaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        size: 18,
                        color: theme.colorScheme.onTertiaryContainer,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'A fee increase has been proposed',
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: theme.colorScheme.onTertiaryContainer,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    proposed.status.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      letterSpacing: 0.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    proposed.summary,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    proposed.impact,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onTertiaryContainer,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        _SourcesCard(guide: guide),
      ],
    );
  }
}

class _TestsTab extends StatelessWidget {
  const _TestsTab({required this.guide});
  final NaturalizationGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final interview = guide.stepByKey('interview');

    return ListView(
      key: const PageStorageKey('guide.tests'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        if (interview != null)
          _SectionCard(
            title: 'On the day',
            subtitle: interview.summary,
            bullets: interview.details,
          ),
        _SectionCard(
          title: 'The English test',
          subtitle: guide.tests.english.summary,
          bullets: guide.tests.english.parts,
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The civics test',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  guide.tests.civics.summary,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 10),
                for (final variant in guide.tests.civics.variants)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant.label,
                          style: theme.textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          variant.detail,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                Text(
                  guide.tests.civics.note,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'If you do not have to take the tests',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                for (final exemption in guide.tests.exemptions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            exemption.label,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            exemption.detail,
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        _SectionCard(
          title: 'If you do not pass',
          subtitle: guide.tests.retake,
          bullets: guide.stepByKey('decision')?.details ?? const [],
        ),
        _SourcesCard(guide: guide),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    this.subtitle,
    this.bullets = const [],
  });

  final String title;
  final String? subtitle;
  final List<String> bullets;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 6),
              Text(subtitle!, style: theme.textTheme.bodyMedium),
            ],
            if (bullets.isNotEmpty) const SizedBox(height: 8),
            for (final bullet in bullets) _Bullet(text: bullet),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('•  ', style: theme.textTheme.bodySmall),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Where this came from and when it was checked — the reader deserves both.
class _SourcesCard extends StatelessWidget {
  const _SourcesCard({required this.guide});
  final NaturalizationGuide guide;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reviewed = guide.reviewedOn;
    final stamp =
        '${reviewed.year}-${reviewed.month.toString().padLeft(2, '0')}-'
        '${reviewed.day.toString().padLeft(2, '0')}';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sources',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            for (final source in guide.sources)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(source.label, style: theme.textTheme.bodySmall),
                    Text(
                      source.url,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ],
                ),
              ),
            const Divider(height: 20),
            Text(
              'Reviewed $stamp. ${guide.disclaimer}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
