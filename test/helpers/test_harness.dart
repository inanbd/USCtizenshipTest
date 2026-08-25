import 'dart:convert';

import 'package:citizenship_test/api/auth_store.dart';
import 'package:citizenship_test/api/civics_api_client.dart';
import 'package:citizenship_test/app.dart';
import 'package:citizenship_test/services/congress_api_service.dart';
import 'package:citizenship_test/services/storage_service.dart';
import 'package:citizenship_test/services/stt_service.dart';
import 'package:citizenship_test/services/tts_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const MethodChannel ttsChannel = MethodChannel('flutter_tts');
const MethodChannel sttChannel = MethodChannel(
  'plugin.csdcorp.com/speech_to_text',
);

/// Records what the mocked text-to-speech engine was asked to say.
class TtsRecorder {
  final List<String> spoken = [];
  int stopCount = 0;
  double? rate;

  void clear() {
    spoken.clear();
    stopCount = 0;
  }
}

/// Controls the mocked speech-to-text engine.
class SttRecorder {
  bool available = true;
  bool listenCalled = false;
  int stopCount = 0;

  void clear() {
    listenCalled = false;
    stopCount = 0;
  }
}

/// Installs mock handlers for the native plugin channels so widget tests can
/// exercise the "hear the question" and "speak the answer" paths without a
/// device.
({TtsRecorder tts, SttRecorder stt}) mockAudioPlugins() {
  final ttsRec = TtsRecorder();
  final sttRec = SttRecorder();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  messenger.setMockMethodCallHandler(ttsChannel, (call) async {
    switch (call.method) {
      case 'speak':
        ttsRec.spoken.add(call.arguments?.toString() ?? '');
        return 1;
      case 'stop':
        ttsRec.stopCount++;
        return 1;
      case 'setSpeechRate':
        ttsRec.rate = (call.arguments as num?)?.toDouble();
        return 1;
      case 'getLanguages':
      case 'getVoices':
      case 'getEngines':
        return <String>[];
      default:
        return 1;
    }
  });

  messenger.setMockMethodCallHandler(sttChannel, (call) async {
    switch (call.method) {
      case 'has_permission':
      case 'initialize':
        return sttRec.available;
      case 'listen':
        sttRec.listenCalled = true;
        return true;
      case 'stop':
      case 'cancel':
        sttRec.stopCount++;
        return true;
      case 'locales':
        return <String>['en_US'];
      default:
        return true;
    }
  });

  return (tts: ttsRec, stt: sttRec);
}

void clearAudioPluginMocks() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(ttsChannel, null);
  messenger.setMockMethodCallHandler(sttChannel, null);
}

/// Simulates the native speech recognizer returning [words] to the app,
/// exactly as the platform plugin would deliver it.
Future<void> emitSpeechResult(String words, {bool isFinal = true}) async {
  final payload = jsonEncode({
    'alternates': [
      {'recognizedWords': words, 'recognizedPhrases': null, 'confidence': 0.95},
    ],
    'resultType': isFinal ? 2 : 0,
  });
  await _invokeOnStt('textRecognition', payload);
}

/// Simulates a status change from the native recognizer (e.g. 'done').
Future<void> emitSpeechStatus(String status) =>
    _invokeOnStt('notifyStatus', status);

Future<void> _invokeOnStt(String method, Object? args) async {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  await messenger.handlePlatformMessage(
    sttChannel.name,
    sttChannel.codec.encodeMethodCall(MethodCall(method, args)),
    (_) {},
  );
}

/// Gives the test a phone-sized-but-tall surface so long scrolling screens
/// render their content without overflowing.
void useTallScreen(WidgetTester tester, {Size size = const Size(1080, 2400)}) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Fresh storage backed by in-memory SharedPreferences.
Future<StorageService> freshStorage([
  Map<String, Object> initial = const {},
]) async {
  SharedPreferences.setMockInitialValues(Map<String, Object>.from(initial));
  return StorageService.create();
}

/// Builds the full app widget wired with real providers and test services.
///
/// [apiClient] lets a test drive the backend-facing behaviour; by default the
/// app is signed out, which is the offline path every study feature must
/// keep working on.
Future<CivicsApp> buildTestApp({
  StorageService? storage,
  http.Client? httpClient,
  CivicsApiClient? apiClient,
}) async {
  final store = storage ?? await freshStorage();
  return CivicsApp(
    storage: store,
    tts: TtsService(),
    stt: SttService(),
    congress: CongressApiService(client: httpClient),
    api: apiClient ?? CivicsApiClient(AuthStore(store), client: httpClient),
  );
}
