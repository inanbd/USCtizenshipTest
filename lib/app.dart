import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/progress_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/study_plan_provider.dart';
import 'screens/home_screen.dart';
import 'services/congress_api_service.dart';
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
  });

  final StorageService storage;
  final TtsService tts;
  final SttService stt;
  final CongressApiService congress;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Plain services (not listenable) shared across the app.
        Provider<TtsService>.value(value: tts),
        Provider<SttService>.value(value: stt),
        Provider<CongressApiService>.value(value: congress),
        // Listenable app state.
        ChangeNotifierProvider(create: (_) => SettingsProvider(storage)),
        ChangeNotifierProvider(create: (_) => ProgressProvider(storage)),
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
