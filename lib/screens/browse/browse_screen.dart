import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/enums.dart';
import '../../models/question.dart';
import '../../providers/progress_provider.dart';
import '../../providers/settings_provider.dart';
import 'question_detail_screen.dart';

enum _Filter { all, senior, starred, notKnown }

class BrowseScreen extends StatefulWidget {
  const BrowseScreen({super.key});

  @override
  State<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends State<BrowseScreen> {
  String _search = '';
  _Filter _filter = _Filter.all;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final progress = context.watch<ProgressProvider>();
    final version = settings.testVersion;
    final all = QuestionRepository.forVersion(version);

    final filtered = all.where((q) {
      if (_search.isNotEmpty) {
        final s = _search.toLowerCase();
        final inText =
            q.prompt.toLowerCase().contains(s) ||
            q.answers.any((a) => a.toLowerCase().contains(s)) ||
            q.id.toString() == s;
        if (!inText) return false;
      }
      return switch (_filter) {
        _Filter.all => true,
        _Filter.senior => q.senior,
        _Filter.starred => progress.isFavorite(version, q.id),
        _Filter.notKnown => !progress.isLearned(version, q.id),
      };
    }).toList();

    // Group by section for display.
    final sections = <String, List<Question>>{};
    for (final q in filtered) {
      sections.putIfAbsent(q.section, () => []).add(q);
    }

    return Scaffold(
      appBar: AppBar(title: Text('Browse · ${version.shortLabel}')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Search questions or answers',
                  prefixIcon: Icon(Icons.search_rounded),
                ),
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                children: [
                  _filterChip('All', _Filter.all),
                  _filterChip('65/20', _Filter.senior),
                  _filterChip('Starred', _Filter.starred),
                  _filterChip('Not yet known', _Filter.notKnown),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        'No questions match.',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 24),
                      children: [
                        for (final entry in sections.entries) ...[
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                            child: Text(
                              entry.key,
                              style: Theme.of(context).textTheme.titleSmall
                                  ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .primary,
                                  ),
                            ),
                          ),
                          ...entry.value.map((q) => _QuestionTile(question: q)),
                        ],
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _filterChip(String label, _Filter filter) {
    final selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = filter),
      ),
    );
  }
}

class _QuestionTile extends StatelessWidget {
  const _QuestionTile({required this.question});
  final Question question;

  @override
  Widget build(BuildContext context) {
    final progress = context.watch<ProgressProvider>();
    final known = progress.isLearned(question.version, question.id);
    final fav = progress.isFavorite(question.version, question.id);
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: known
            ? scheme.primary
            : scheme.surfaceContainerHighest,
        foregroundColor: known ? scheme.onPrimary : scheme.onSurfaceVariant,
        child: known
            ? const Icon(Icons.check_rounded, size: 18)
            : Text('${question.id}', style: const TextStyle(fontSize: 13)),
      ),
      title: Text(
        question.prompt,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (fav) Icon(Icons.star_rounded, size: 18, color: scheme.secondary),
          if (question.senior)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Icon(
                Icons.elderly_rounded,
                size: 16,
                color: scheme.tertiary,
              ),
            ),
          const Icon(Icons.chevron_right_rounded),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => QuestionDetailScreen(question: question),
        ),
      ),
    );
  }
}
