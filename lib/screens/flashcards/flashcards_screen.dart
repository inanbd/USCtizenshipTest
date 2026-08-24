import 'dart:math';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/question_repository.dart';
import '../../models/question.dart';
import '../../providers/progress_provider.dart';
import '../../providers/settings_provider.dart';
import '../../widgets/answer_reveal.dart';
import '../../widgets/speaker_button.dart';

class FlashcardsScreen extends StatefulWidget {
  const FlashcardsScreen({super.key});

  @override
  State<FlashcardsScreen> createState() => _FlashcardsScreenState();
}

class _FlashcardsScreenState extends State<FlashcardsScreen> {
  final PageController _controller = PageController();
  late List<Question> _cards;
  int _current = 0;
  bool _seniorOnly = false;

  @override
  void initState() {
    super.initState();
    final settings = context.read<SettingsProvider>();
    _seniorOnly = settings.seniorOnly;
    _rebuild(shuffle: false);
  }

  void _rebuild({required bool shuffle}) {
    final version = context.read<SettingsProvider>().testVersion;
    _cards = _seniorOnly
        ? QuestionRepository.senior(version)
        : List.of(QuestionRepository.forVersion(version));
    if (shuffle) _cards.shuffle(Random());
    _current = 0;
    if (_controller.hasClients) _controller.jumpToPage(0);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Flashcards'),
        actions: [
          IconButton(
            tooltip: 'Shuffle',
            icon: const Icon(Icons.shuffle_rounded),
            onPressed: () => setState(() => _rebuild(shuffle: true)),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  Text('${_current + 1} / ${_cards.length}',
                      style: theme.textTheme.labelLarge),
                  const Spacer(),
                  FilterChip(
                    label: const Text('65/20 only'),
                    selected: _seniorOnly,
                    onSelected: (v) => setState(() {
                      _seniorOnly = v;
                      _rebuild(shuffle: false);
                    }),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _cards.length,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (context, i) => _Flashcard(question: _cards[i]),
              ),
            ),
            _NavBar(
              onPrev: _current > 0
                  ? () => _controller.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      )
                  : null,
              onNext: _current < _cards.length - 1
                  ? () => _controller.nextPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _Flashcard extends StatefulWidget {
  const _Flashcard({required this.question});
  final Question question;

  @override
  State<_Flashcard> createState() => _FlashcardState();
}

class _FlashcardState extends State<_Flashcard> {
  bool _flipped = false;

  @override
  void didUpdateWidget(covariant _Flashcard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.question.id != widget.question.id) _flipped = false;
  }

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
    final known = progress.isLearned(q.version, q.id);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _flipped = !_flipped),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Card(
                  key: ValueKey(_flipped),
                  color: _flipped
                      ? theme.colorScheme.surfaceContainerHigh
                      : theme.colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: SingleChildScrollView(
                        child: _flipped
                            ? AnswerReveal(
                                question: q,
                                acceptedAnswers:
                                    accepted.isEmpty ? q.answers : accepted,
                                unresolved: unresolved,
                              )
                            : Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text('Q${q.id}',
                                      style: theme.textTheme.labelLarge
                                          ?.copyWith(
                                        color: theme
                                            .colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.7),
                                      )),
                                  const SizedBox(height: 12),
                                  Text(
                                    q.prompt,
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(
                                      color: theme
                                          .colorScheme.onPrimaryContainer,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text('Tap to flip',
                                      style: theme.textTheme.labelMedium
                                          ?.copyWith(
                                        color: theme
                                            .colorScheme.onPrimaryContainer
                                            .withValues(alpha: 0.6),
                                      )),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              SpeakerButton(text: _flipped
                  ? (accepted.isEmpty ? q.answers.first : accepted.first)
                  : q.prompt),
              const Spacer(),
              IconButton.filledTonal(
                onPressed: () => progress.toggleFavorite(q.version, q.id),
                icon: Icon(progress.isFavorite(q.version, q.id)
                    ? Icons.star_rounded
                    : Icons.star_border_rounded),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: () => progress.toggleLearned(q.version, q.id),
                icon: Icon(known
                    ? Icons.check_circle_rounded
                    : Icons.circle_outlined),
                label: Text(known ? 'Known' : 'Learn'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavBar extends StatelessWidget {
  const _NavBar({this.onPrev, this.onNext});
  final VoidCallback? onPrev;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrev,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Previous'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Next'),
            ),
          ),
        ],
      ),
    );
  }
}
