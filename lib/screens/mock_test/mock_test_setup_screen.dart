import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/enums.dart';
import '../../models/question.dart';
import '../../providers/mock_test_controller.dart';
import '../../providers/progress_provider.dart';
import '../../providers/settings_provider.dart';
import '../settings/state_info_screen.dart';
import 'mock_test_screen.dart';

enum _Source { all, senior, starred }

class MockTestSetupScreen extends StatefulWidget {
  const MockTestSetupScreen({super.key});

  @override
  State<MockTestSetupScreen> createState() => _MockTestSetupScreenState();
}

class _MockTestSetupScreenState extends State<MockTestSetupScreen> {
  _Source _source = _Source.all;
  late int _count;

  @override
  void initState() {
    super.initState();
    _count = context.read<SettingsProvider>().testVersion.askedCount;
  }

  List<Question> _pool(TestVersion version, ProgressProvider progress) {
    switch (_source) {
      case _Source.all:
        return List.of(QuestionRepository.forVersion(version));
      case _Source.senior:
        return QuestionRepository.senior(version);
      case _Source.starred:
        final favs = progress.favoritesFor(version);
        return QuestionRepository.forVersion(version)
            .where((q) => favs.contains(q.id))
            .toList();
    }
  }

  void _start() {
    final settings = context.read<SettingsProvider>();
    final progress = context.read<ProgressProvider>();
    final version = settings.testVersion;
    final pool = _pool(version, progress);
    if (pool.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No questions in this set to test.')),
      );
      return;
    }
    pool.shuffle(Random());
    final selected = pool.take(min(_count, pool.length)).toList();
    final controller = MockTestController(
      version: version,
      questions: selected,
      officials: settings.officials,
      state: settings.stateInfo,
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ChangeNotifierProvider.value(
        value: controller,
        child: const MockTestScreen(),
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final settings = context.watch<SettingsProvider>();
    final progress = context.watch<ProgressProvider>();
    final version = settings.testVersion;
    final poolSize = _pool(version, progress).length;
    final maxCount = max(1, poolSize);
    final effectiveCount = min(_count, maxCount);
    final hasState = settings.stateInfo != null;

    return Scaffold(
      appBar: AppBar(title: const Text('Mock Test')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: theme.colorScheme.secondaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.record_voice_over_rounded,
                        color: theme.colorScheme.onSecondaryContainer),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You can read or hear each question, and type or speak '
                        'your answer. Pass by answering ${version.passCount} of '
                        '${version.askedCount} correctly.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text('Question source',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            SegmentedButton<_Source>(
              segments: const [
                ButtonSegment(value: _Source.all, label: Text('All')),
                ButtonSegment(value: _Source.senior, label: Text('65/20')),
                ButtonSegment(value: _Source.starred, label: Text('Starred')),
              ],
              selected: {_source},
              onSelectionChanged: (s) => setState(() => _source = s.first),
            ),
            const SizedBox(height: 8),
            Text('$poolSize questions available in this set.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
            const SizedBox(height: 24),
            Text('Number of questions',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w600)),
            Slider(
              value: effectiveCount.toDouble(),
              min: 1,
              max: maxCount.toDouble(),
              divisions: maxCount > 1 ? maxCount - 1 : null,
              label: '$effectiveCount',
              onChanged: (v) => setState(() => _count = v.round()),
            ),
            Center(
              child: Text('$effectiveCount questions',
                  style: theme.textTheme.titleLarge),
            ),
            const SizedBox(height: 16),
            if (!hasState)
              Card(
                child: ListTile(
                  leading: Icon(Icons.location_on_outlined,
                      color: theme.colorScheme.tertiary),
                  title: const Text('Set your state'),
                  subtitle: const Text(
                      'So state-specific questions can be graded.'),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const StateInfoScreen(),
                  )),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: poolSize == 0 ? null : _start,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('Start test'),
            ),
          ],
        ),
      ),
    );
  }
}
