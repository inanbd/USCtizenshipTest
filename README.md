# Civics Prep — U.S. Citizenship Test study app

[![CI](https://github.com/inanbd/USCtizenshipTest/actions/workflows/ci.yml/badge.svg)](https://github.com/inanbd/USCtizenshipTest/actions/workflows/ci.yml)
[![Release](https://github.com/inanbd/USCtizenshipTest/actions/workflows/release.yml/badge.svg)](https://github.com/inanbd/USCtizenshipTest/actions/workflows/release.yml)
[![Backend CI](https://github.com/inanbd/USCtizenshipTest/actions/workflows/backend-ci.yml/badge.svg)](https://github.com/inanbd/USCtizenshipTest/actions/workflows/backend-ci.yml)

A Flutter app, a .NET 10 backend and a Blazor website for learning and practising
the USCIS civics (naturalization) test. It bundles **all three** official
question sets — including the **2025 test** taken by anyone who filed Form N-400
on or after 20 October 2025 — runs mock tests where you can **see and hear** each
question and **type or speak** your answer, generates a **study plan** from your
test date, shows **flashcards**, and pulls the **state-specific** answers for
where you live from the backend.

> ⚠️ Study aid only — not affiliated with USCIS. Some answers change with
> elections/appointments or depend on your address. Always verify current
> answers at **uscis.gov/citizenship/testupdates**.

## What is in this repository

| Path | What it is |
|---|---|
| `lib/`, `test/`, `android/` | The Flutter mobile app (Android) |
| `backend/` | .NET 10 solution: API, Blazor website, and their tests |
| `data/` | The naturalization process guide — authored once, used by all three |

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

- **Three official question sets, user-selectable**
  - **2025 test — 128 questions** (20 asked, pass with 12) — *the default*, and
    the exam taken if you filed Form N-400 on or after 20 Oct 2025
  - 2008 test — 100 questions (10 asked, pass with 6) — if you filed before then
  - 2020 test — 128 questions — withdrawn in 2021, kept for reference
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
- **State-specific answers, fetched and cached**
  - State capitals are **bundled**, so they work with no network at all
  - Governor, senators and your state's whole House delegation come from the
    backend in one call (`/api/states/{code}/answers`) — the server owns the
    Congress.gov key and a maintained governors table, so no key ships in the app
  - You **pick your representative** from the state's list, because only you
    know your congressional district
  - The last fetch is **cached on the device**, so the answers are there offline;
    a failed refresh keeps what you already have rather than clearing it
  - Every field stays editable, and **anything you type wins** over a later fetch
  - A build with no backend configured falls back to your own free
    [Congress.gov API](https://api.congress.gov) key
- **The naturalization process, end to end** — the seven steps from checking
  you qualify to taking the oath, with how long each usually takes
  - **How to apply**: filing online vs. by mail, and what to have ready first
  - **What it costs**: the current fees, the reduced fee and the fee waiver,
    plus any proposed change clearly flagged as *not in effect*
  - **The interview**: the English test, which civics set your filing date buys
    you, the 50/20 · 55/15 · 65/20 exemptions, and what happens if you fail
  - Reads offline from a bundled copy; the server can publish a newer one
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

### State answers

**Settings › My state info › Fetch my state answers** pulls the capital,
governor, senators and your state's House delegation from the backend, then asks
which representative is yours. The result is cached, so it works offline
afterwards.

If this build has no backend URL (`--dart-define=API_BASE_URL=…`), the app falls
back to your own Congress.gov key:

1. Get a free key at <https://api.congress.gov/sign-up/>.
2. In the app: **Settings › Current officials › Congress.gov API key**.

With neither, the bundled capital still answers its question and you type the
rest — and whatever you type is kept through later fetches.

## Project structure

```
lib/
  models/        Question, StateInfo, Officials, StudyPlan, TestResult, enums
  data/          Official 2008 (100), 2020 (128) & 2025 (128) question sets,
                 state capitals, QuestionRepository (resolves dynamic answers)
  services/      TTS, STT, storage, answer matcher, study-plan generator,
                 state answers (backend + cache), naturalization guide,
                 Congress.gov API client
  providers/     Settings, Progress, StudyPlan, MockTest (ChangeNotifier)
  screens/       home, mock_test/, flashcards/, study_plan/, browse/, guide/,
                 settings/
  widgets/       SpeakerButton, AnswerReveal
  theme/         app theme
test/
  data/          dataset integrity (all three sets, incl. the 2025 changes)
                 + dynamic answer resolution
  models/        JSON round-trips for everything persisted to disk
  services/      answer matcher, study plan generator, Congress.gov client,
                 state answers (fetch, cache, manual override), the guide
  providers/     settings/progress/study-plan persistence, mock-test controller
  screens/       end-to-end widget tests for every feature
  api/           API client and progress sync
  helpers/       plugin channel mocks (TTS/STT) and test fixtures
```

The app also has `lib/api/` (backend client, session storage) and
`lib/providers/auth_provider.dart` + `progress_sync.dart`, which sync progress
with the backend when the user is signed in.

## Testing

308 tests cover the app end to end:

```bash
flutter test
```

- **Dataset integrity** pins all three official sets to the USCIS structure —
  100/128/128 questions, the exact 20 asterisked 65/20 questions in each, which
  questions are state-dependent vs. time-sensitive, and the required answer
  counts. The eight wording and answer changes M-1778 (09/25) made to the 2020
  set are pinned individually, so a regeneration cannot silently undo them.
- **State answers** cover the fetch-cache-override contract: a cached payload
  works offline, a failed refresh never wipes it, and a name you typed survives
  the next fetch.
- **The process guide** is pinned to the steps in the order an applicant lives
  them, the current fees, and the rule that a *proposed* fee never renders as
  the current one. The bundled copy must read with no backend at all, and a
  server copy only replaces it when it was reviewed more recently.
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

The backend has its own 142 tests; see [`backend/README.md`](backend/README.md).

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

## The naturalization guide

`data/naturalization_guide.json` is the single source for the process content:
the steps and their timings, how to apply, the fees, and the test rules. The
Flutter app bundles it as an asset (so it reads offline), the backend embeds the
same file and serves it at `GET /api/guide`, and the website renders it at
`/process`. `backend/tools/export_seed_data.py` copies and validates it, and CI
fails if the two copies drift.

It carries a `reviewedOn` date, shown wherever the guide is. When the server's
copy is newer than the one bundled in an installed app, the app takes the
server's — so a fee change reaches users without an app release.

## Data sources & accuracy

- Questions and accepted answers are the official USCIS civics questions
  (2008, 2020 and 2025 versions). The 2025 set is M-1778 (09/25).
- Process steps, timings and fees are from **uscis.gov**, with the review date
  shown on every screen that uses them. Processing times are typical ranges, not
  promises — look up your own field office.
- Answers marked as depending on your **state** or on **current officeholders**
  are resolved at runtime and flagged in the UI. Governors come from a table the
  backend maintains, stamped with the date it was last verified; senators and
  representatives come from Congress.gov. Verify current officials at
  **uscis.gov/citizenship/testupdates** before your interview.
