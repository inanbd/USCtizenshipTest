# Civics Prep — U.S. Citizenship Test study app

A Flutter app to learn and practice the USCIS civics (naturalization) test. It
bundles **both** official question sets, runs mock tests where you can **see and
hear** each question and **type or speak** your answer, generates a **study
plan** from your test date, shows **flashcards**, and resolves the
**state-specific** answers for where you live.

> ⚠️ Study aid only — not affiliated with USCIS. Some answers change with
> elections/appointments or depend on your address. Always verify current
> answers at **uscis.gov/citizenship/testupdates**.

## Features

- **Two official question sets, user-selectable**
  - 2008 test — 100 questions (10 asked, pass with 6)
  - 2020 test — 128 questions (20 asked, pass with 12)
  - 65/20 exemption filter (the 20 asterisked questions) throughout
- **Mock test** — randomized from all / 65-20 / starred questions
  - Read the question **or hear it** (text-to-speech)
  - **Type your answer or speak it** (speech-to-text)
  - Lenient auto-grading (ignores case/punctuation/parenthetical hints,
    tolerates typos & speech slips, and handles "name two/three" questions),
    with a manual "right / wrong" override
  - Scored result screen with a full review, saved to history
- **Flashcards** — flip through every question with audio, shuffle, mark known /
  starred, filter to 65/20
- **Study plan** — pick your interview date and the app spreads all questions
  across the days with periodic review days; check days off as you go
- **Browse** — every question grouped by USCIS topic, searchable, with audio and
  tap-to-reveal answers
- **State-specific answers (hybrid data)**
  - State capitals are **bundled** (work offline)
  - Governor / U.S. senators / U.S. representative are entered by you, or
    **refreshed live** from the official [Congress.gov API](https://api.congress.gov)
    with a free API key
- **Editable "current officials"** for the time-sensitive federal questions
  (President, VP, Speaker, Chief Justice, President's party)
- Light / dark / system theme, adjustable speech speed, progress persistence

## Getting started

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.13+; developed against stable 3.47) and the Android toolchain.

```bash
flutter pub get
flutter run                 # run on a connected device/emulator
flutter test                # run the unit/widget tests
flutter build apk --release # build a release APK
```

The app targets **Android** (microphone + internet permissions are declared in
`android/app/src/main/AndroidManifest.xml`). TTS/STT use the device's built-in
engines.

### Optional: live state data

To refresh your state's senators and representatives from Congress.gov:

1. Get a free key at <https://api.congress.gov/sign-up/>.
2. In the app: **Settings › Current officials › Congress.gov API key**.
3. **Settings › My state info › Refresh reps from Congress.gov**.

Without a key, the app uses the bundled capital plus any names you enter by hand.

## Project structure

```
lib/
  models/        Question, StateInfo, Officials, StudyPlan, TestResult, enums
  data/          Official 2008 (100) & 2020 (128) question sets, state capitals,
                 QuestionRepository (resolves dynamic answers)
  services/      TTS, STT, storage, answer matcher, study-plan generator,
                 Congress.gov API client
  providers/     Settings, Progress, StudyPlan, MockTest (ChangeNotifier)
  screens/       home, mock_test/, flashcards/, study_plan/, browse/, settings/
  widgets/       SpeakerButton, AnswerReveal
  theme/         app theme
test/            answer matcher, study plan, dataset integrity, widget smoke test
```

## Data sources & accuracy

- Questions and accepted answers are the official USCIS civics questions
  (2008 and 2020 versions).
- Answers marked as depending on your **state** or on **current officeholders**
  are resolved at runtime and flagged in the UI. Verify current officials at
  **uscis.gov/citizenship/testupdates** before your interview.
