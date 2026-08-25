import 'dart:async';

import 'package:flutter/material.dart';

import 'api/auth_store.dart';
import 'api/civics_api_client.dart';
import 'app.dart';
import 'services/congress_api_service.dart';
import 'services/storage_service.dart';
import 'services/stt_service.dart';
import 'services/tts_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final storage = await StorageService.create();
  final tts = TtsService();
  final stt = SttService();
  final congress = CongressApiService();
  // The app talks to the backend for accounts and cross-device progress; the
  // bundled question set keeps every study feature working offline.
  final api = CivicsApiClient(AuthStore(storage));
  api.restore();
  // Warm up TTS in the background; ignore failures on unsupported devices.
  unawaited(tts.init());
  runApp(
    CivicsApp(
      storage: storage,
      tts: tts,
      stt: stt,
      congress: congress,
      api: api,
    ),
  );
}
