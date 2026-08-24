import 'package:citizenship_test/app.dart';
import 'package:citizenship_test/services/congress_api_service.dart';
import 'package:citizenship_test/services/storage_service.dart';
import 'package:citizenship_test/services/stt_service.dart';
import 'package:citizenship_test/services/tts_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('app boots to the home screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final storage = await StorageService.create();

    await tester.pumpWidget(
      CivicsApp(
        storage: storage,
        tts: TtsService(),
        stt: SttService(),
        congress: CongressApiService(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('U.S. Citizenship Test'), findsOneWidget);
    expect(find.text('Mock Test'), findsOneWidget);
    expect(find.text('Flashcards'), findsOneWidget);
  });
}
