import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

/// Speaks question and answer text aloud so the user can *hear* the question.
class TtsService {
  final FlutterTts _tts = FlutterTts();
  bool _initialized = false;

  final ValueNotifier<bool> speaking = ValueNotifier(false);

  Future<void> init({double rate = 0.45, double pitch = 1.0}) async {
    if (_initialized) return;
    try {
      await _tts.setLanguage('en-US');
      await _tts.setSpeechRate(rate);
      await _tts.setPitch(pitch);
      await _tts.setVolume(1.0);
      _tts.setCompletionHandler(() => speaking.value = false);
      _tts.setCancelHandler(() => speaking.value = false);
      _tts.setErrorHandler((_) => speaking.value = false);
      _initialized = true;
    } catch (e) {
      debugPrint('TTS init failed: $e');
    }
  }

  Future<void> setRate(double rate) async {
    try {
      await _tts.setSpeechRate(rate);
    } catch (_) {}
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    await init();
    try {
      await _tts.stop();
      speaking.value = true;
      await _tts.speak(text);
    } catch (e) {
      speaking.value = false;
      debugPrint('TTS speak failed: $e');
    }
  }

  Future<void> stop() async {
    try {
      await _tts.stop();
    } catch (_) {}
    speaking.value = false;
  }

  void dispose() {
    speaking.dispose();
  }
}
