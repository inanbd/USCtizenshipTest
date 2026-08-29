import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'api/civics_api_client.dart';
import 'providers/auth_provider.dart';
import 'providers/progress_provider.dart';
import 'providers/progress_sync.dart';
import 'providers/settings_provider.dart';
import 'providers/study_plan_provider.dart';
import 'screens/home_screen.dart';
import 'services/congress_api_service.dart';
import 'services/state_answers_service.dart';
import 'services/storage_service.dart';
import 'services/stt_service.dart';
import 'services/tts_service.dart';
import 'theme/app_theme.dart';

class CivicsApp extends StatelessWidget {
  const CivicsApp({
    super.key,
    required this.storage,
    required this.tts,
    required this.stt,
    required this.congress,
    required this.api,
  });

  final StorageService storage;
  final TtsService tts;
  final SttService stt;
  final CongressApiService congress;
  final CivicsApiClient api;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Plain services (not listenable) shared across the app.
        Provider<TtsService>.value(value: tts),
        Provider<SttService>.value(value: stt),
        Provider<CongressApiService>.value(value: congress),
        Provider<CivicsApiClient>.value(value: api),
        // Derived from the client so it always talks to the current one.
        ProxyProvider<CivicsApiClient, StateAnswersService>(
          update: (_, client, _) =>
              StateAnswersService(client, storage, congress: congress),
        ),
        // Listenable app state.
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => AuthProvider(api)),
        ChangeNotifierProvider(create: (_) => ProgressProvider(storage)),
        // Bridges local progress and the backend once the user signs in.
        ProxyProvider<ProgressProvider, ProgressSync>(
          update: (_, progress, _) => ProgressSync(api, progress),
        ),
        ChangeNotifierProvider(create: (_) => StudyPlanProvider(storage)),
      ],
      child: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'Civics Prep',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: settings.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
