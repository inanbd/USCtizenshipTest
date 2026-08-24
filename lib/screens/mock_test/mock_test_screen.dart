import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/mock_test_controller.dart';
import '../../providers/progress_provider.dart';
import '../../services/stt_service.dart';
import '../../widgets/speaker_button.dart';
import 'mock_test_result_screen.dart';

class MockTestScreen extends StatefulWidget {
  const MockTestScreen({super.key});

  @override
  State<MockTestScreen> createState() => _MockTestScreenState();
}

class _MockTestScreenState extends State<MockTestScreen> {
  final TextEditingController _answerCtrl = TextEditingController();
  bool _submitted = false;
  bool _lastCorrect = false;

  @override
  void dispose() {
    _answerCtrl.dispose();
    super.dispose();
  }

  Future<void> _toggleMic() async {
    final stt = context.read<SttService>();
    if (stt.listening.value) {
      await stt.stop();
      return;
    }
    final ok = await stt.init();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Speech recognition unavailable. Check microphone permission.',
          ),
        ),
      );
      return;
    }
    await stt.start(
      onResult: (text, isFinal) {
        _answerCtrl.text = text;
        _answerCtrl.selection = TextSelection.fromPosition(
          TextPosition(offset: _answerCtrl.text.length),
        );
      },
    );
  }

  void _submit(MockTestController controller) {
    context.read<SttService>().stop();
    final correct = controller.submit(_answerCtrl.text);
    setState(() {
      _submitted = true;
      _lastCorrect = correct;
    });
  }

  void _next(MockTestController controller) {
    if (controller.isFinished) {
      _finish(controller);
      return;
    }
    controller.next();
    _answerCtrl.clear();
    setState(() => _submitted = false);
  }

  Future<void> _finish(MockTestController controller) async {
    final result = controller.buildResult();
    final progress = context.read<ProgressProvider>();
    await progress.addResult(result);
    // Mark correctly-answered questions as known.
    for (final a in result.answers.where((a) => a.correct)) {
      await progress.setLearned(controller.version, a.questionId, true);
    }
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => MockTestResultScreen(result: result)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<MockTestController>();
    final theme = Theme.of(context);
    final q = controller.current;
    final accepted = controller.acceptedFor(q);
    final ungradable = accepted.isEmpty;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _confirmQuit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            'Question ${controller.index + 1} of ${controller.total}',
          ),
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            onPressed: _confirmQuit,
          ),
        ),
        body: SafeArea(
          child: Column(
            children: [
              LinearProgressIndicator(
                value: (controller.index) / controller.total,
                minHeight: 4,
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Row(
                      children: [
                        _ScorePill(
                          label: 'Correct',
                          value: '${controller.correctSoFar}',
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 8),
                        _ScorePill(
                          label: 'Need',
                          value: '${controller.passMark}',
                          color: theme.colorScheme.secondary,
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Card(
                      color: theme.colorScheme.primaryContainer,
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Q${q.id}',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer
                                    .withValues(alpha: 0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              q.prompt,
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SpeakerButton(text: q.prompt),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (!_submitted)
                      _answerInput(controller, ungradable)
                    else
                      _feedback(controller, accepted, ungradable),
                  ],
                ),
              ),
              _bottomBar(controller),
            ],
          ),
        ),
      ),
    );
  }

  Widget _answerInput(MockTestController controller, bool ungradable) {
    final stt = context.read<SttService>();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _answerCtrl,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Your answer',
            hintText: 'Type your answer, or tap the mic to speak',
            suffixIcon: ValueListenableBuilder<bool>(
              valueListenable: stt.listening,
              builder: (context, listening, _) => IconButton(
                onPressed: _toggleMic,
                icon: Icon(
                  listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                ),
                color: listening
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.primary,
                tooltip: listening ? 'Stop' : 'Speak answer',
              ),
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: stt.listening,
          builder: (context, listening, _) => listening
              ? Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Listening…',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (ungradable)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'This answer depends on your state/current officials, so it will '
              'be self-graded.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.tertiary),
            ),
          ),
      ],
    );
  }

  Widget _feedback(
    MockTestController controller,
    List<String> accepted,
    bool ungradable,
  ) {
    final theme = Theme.of(context);
    final q = controller.current;
    final display = accepted.isEmpty ? q.answers : accepted;
    final color = _lastCorrect
        ? theme.colorScheme.primary
        : theme.colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                _lastCorrect
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                color: color,
              ),
              const SizedBox(width: 10),
              Text(
                ungradable
                    ? 'Self-graded'
                    : (_lastCorrect ? 'Correct!' : 'Not quite'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Accepted answer${display.length > 1 ? "s" : ""}:',
          style: theme.textTheme.labelLarge,
        ),
        const SizedBox(height: 6),
        ...display.map(
          (a) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(a)),
              ],
            ),
          ),
        ),
        if (q.note != null) ...[
          const SizedBox(height: 8),
          Text(
            q.note!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
        const SizedBox(height: 16),
        Row(
          children: [
            Text('Score this yourself:', style: theme.textTheme.bodyMedium),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                controller.overrideLast(correct: true);
                setState(() => _lastCorrect = true);
              },
              icon: const Icon(Icons.thumb_up_rounded, size: 18),
              label: const Text('Right'),
            ),
            TextButton.icon(
              onPressed: () {
                controller.overrideLast(correct: false);
                setState(() => _lastCorrect = false);
              },
              icon: const Icon(Icons.thumb_down_rounded, size: 18),
              label: const Text('Wrong'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _bottomBar(MockTestController controller) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: !_submitted
                ? FilledButton.icon(
                    onPressed: () => _submit(controller),
                    icon: const Icon(Icons.check_rounded),
                    label: const Text('Submit answer'),
                  )
                : FilledButton.icon(
                    onPressed: () => _next(controller),
                    icon: Icon(
                      controller.isFinished
                          ? Icons.flag_rounded
                          : Icons.arrow_forward_rounded,
                    ),
                    label: Text(controller.isFinished ? 'See results' : 'Next'),
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmQuit() async {
    final quit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Quit test?'),
        content: const Text('Your progress in this test will be lost.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep going'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Quit'),
          ),
        ],
      ),
    );
    if (quit == true && mounted) {
      context.read<SttService>().stop();
      Navigator.of(context).pop();
    }
  }
}

class _ScorePill extends StatelessWidget {
  const _ScorePill({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Text(
            '$value ',
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
