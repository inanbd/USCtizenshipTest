import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/tts_service.dart';

/// A button that reads the given [text] aloud (hear the question).
class SpeakerButton extends StatelessWidget {
  const SpeakerButton({
    super.key,
    required this.text,
    this.label = 'Hear',
    this.compact = false,
  });

  final String text;
  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final tts = context.read<TtsService>();
    return ValueListenableBuilder<bool>(
      valueListenable: tts.speaking,
      builder: (context, speaking, _) {
        final icon = speaking ? Icons.stop_rounded : Icons.volume_up_rounded;
        onPressed() => speaking ? tts.stop() : tts.speak(text);
        if (compact) {
          return IconButton(
            onPressed: onPressed,
            icon: Icon(icon),
            tooltip: speaking ? 'Stop' : 'Hear it',
          );
        }
        return OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(speaking ? 'Stop' : label),
        );
      },
    );
  }
}
