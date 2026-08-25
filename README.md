# Civics Prep — U.S. Citizenship Test study app

[![CI](https://github.com/inanbd/USCtizenshipTest/actions/workflows/ci.yml/badge.svg)](https://github.com/inanbd/USCtizenshipTest/actions/workflows/ci.yml)
[![Release](https://github.com/inanbd/USCtizenshipTest/actions/workflows/release.yml/badge.svg)](https://github.com/inanbd/USCtizenshipTest/actions/workflows/release.yml)
[![Backend CI](https://github.com/inanbd/USCtizenshipTest/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/inanbd/USCtizenshipTest/actions/workflows/backend-ci.yml)

A Flutter app, a .NET 10 backend and a Blazor website for learning and practising
the USCIS civics (naturalization) test. It
bundles **both** official question sets, runs mock tests where you can **see and
hear** each question and **type or speak** your answer, generates a **study
plan** from your test date, shows **flashcards**, and resolves the
**state-specific** answers for where you live.

> ⚠️ Study aid only — not affiliated with USCIS. Some answers change with
> elections/appointments or depend on your address. Always verify current
> answers at **uscis.gov/citizenship/testupdates**.

## What is in this repository

| Path | What it is |
|---|---|
| `lib/`, `test/`, `android/` | The Flutter mobile app (Android) |
| `backend/` | .NET 10 solution: API, Blazor website, and their tests |

The app works fully offline against its bundled question set. Signing in adds an
account whose progress, study plan and test history sync with the website
through the backend. See [`backend/README.md`](backend/README.md) for the
architecture, configuration and API reference.

### Running the whole stack

```bash
# 1. Backend + SQL Server
cd backend && docker compose up --build      # API on http://localhost:5199

# 2. Website
dotnet run --project backend/src/CivicsPrep.Web

# 3. App, pointed at the local backend
#    10.0.2.2 is how the Android emulator reaches the host machine
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5199
```

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
flutter test                # run the full test suite
flutter analyze             # static analysis
dart format .               # canonical formatting (CI enforces this)
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
test/
  data/          dataset integrity (both official sets) + dynamic answer resolution
  models/        JSON round-trips for everything persisted to disk
  services/      answer matcher, study plan generator, Congress.gov client
  providers/     settings/progress/study-plan persistence, mock-test controller
  screens/       end-to-end widget tests for every feature
  api/           API client and progress sync
  helpers/       plugin channel mocks (TTS/STT) and test fixtures
```

The app also has `lib/api/` (backend client, session storage) and
`lib/providers/auth_provider.dart` + `progress_sync.dart`, which sync progress
with the backend when the user is signed in.

## Testing

240 tests cover the app end to end:

```bash
flutter test
```

- **Dataset integrity** pins both official sets to the USCIS structure — 100/128
  questions, the exact 20 asterisked 65/20 questions in each, which questions are
  state-dependent vs. time-sensitive, and the required answer counts.
- **Answer matching** covers lenient grading (case, punctuation, parentheticals,
  typos, spoken slips) *and* the cases that must stay strict: "Vice President" is
  never accepted for "the President", negated answers are rejected, and one vague
  word cannot satisfy a "name two" question.
- **Widget tests** drive real user flows, including hearing a question and
  speaking an answer — the native TTS and speech-to-text channels are mocked in
  `test/helpers/test_harness.dart`, so a simulated recognition result flows into
  the answer field and gets graded just as it would on a device.
- **Backend client tests** cover sign-in, token refresh-and-retry on a 401, and
  the progress sync — including that a signed-out app never calls the network and
  that a failed sync never surfaces as an error to the user.

The backend has its own 125 tests; see [`backend/README.md`](backend/README.md).

## Continuous integration and releases

- **`.github/workflows/ci.yml`** — on every push and pull request: format check,
  `flutter analyze`, the full test suite, then a release APK build.
- **`.github/workflows/release.yml`** — on a `v*` tag: re-runs all checks, builds
  the universal APK, per-ABI APKs and an App Bundle, and publishes them to a
  GitHub Release with checksums.
- **`.github/workflows/backend-ci.yml`** — builds and tests the .NET solution,
  publishes the API and website, and fails if the backend's seed data has drifted
  from the app's question datasets.

To cut a release:

```bash
git tag v1.0.0
git push origin v1.0.0
```

> Released APKs are signed with Flutter's **debug** key so they install directly
> for testing. Add your own keystore before publishing to the Play Store.

## Data sources & accuracy

- Questions and accepted answers are the official USCIS civics questions
  (2008 and 2020 versions).
- Answers marked as depending on your **state** or on **current officeholders**
  are resolved at runtime and flagged in the UI. Verify current officials at
  **uscis.gov/citizenship/testupdates** before your interview.
