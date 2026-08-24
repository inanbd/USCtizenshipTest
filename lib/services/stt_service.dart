import 'package:flutter/foundation.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps on-device speech recognition so the user can *speak* their answer.
class SttService {
  final SpeechToText _speech = SpeechToText();
  bool _available = false;
  bool _initTried = false;

  final ValueNotifier<bool> listening = ValueNotifier(false);

  bool get isAvailable => _available;

  /// Initializes the plugin and requests microphone permission. Returns true
  /// if speech recognition is available on this device.
  Future<bool> init() async {
    if (_initTried) return _available;
    _initTried = true;
    try {
      _available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            listening.value = false;
          }
        },
        onError: (_) => listening.value = false,
      );
    } catch (e) {
      debugPrint('STT init failed: $e');
      _available = false;
    }
    return _available;
  }

  /// Starts listening. [onResult] is called with the (partial then final)
  /// recognized text.
  Future<void> start({
    required void Function(String text, bool isFinal) onResult,
  }) async {
    final ok = await init();
    if (!ok) return;
    try {
      listening.value = true;
      await _speech.listen(
        onResult: (r) => onResult(r.recognizedWords, r.finalResult),
        listenOptions: SpeechListenOptions(
          partialResults: true,
          cancelOnError: true,
          listenFor: const Duration(seconds: 20),
          pauseFor: const Duration(seconds: 3),
          localeId: 'en_US',
        ),
      );
    } catch (e) {
      debugPrint('STT listen failed: $e');
      listening.value = false;
    }
  }

  /// Stops an in-progress recognition. Calling the plugin when we are not
  /// listening schedules needless work, so this is a no-op in that case.
  Future<void> stop() async {
    if (!listening.value) return;
    listening.value = false;
    try {
      await _speech.stop();
    } catch (_) {}
  }

  void dispose() {
    listening.dispose();
  }
}
