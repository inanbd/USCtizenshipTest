# Civics Prep backend and website

A .NET 10 backend and Blazor WebAssembly website for the U.S. citizenship civics
test, built with Clean Architecture and CQRS over SQL Server. The Flutter mobile
app and the website are both clients of this API.

## Architecture

Dependencies point inwards; nothing in an inner layer knows about an outer one.

```
CivicsPrep.Domain          entities, enums, and the rules that define the app
   ^                       (answer matching, study-plan generation, pass marks)
CivicsPrep.Application     CQRS commands/queries (MediatR), DTO projections,
   ^                       FluentValidation, and the ports (interfaces) it needs
CivicsPrep.Infrastructure  EF Core + SQL Server, ASP.NET Identity, JWT,
   ^                       Congress.gov client, database seeding
CivicsPrep.Api             thin controllers over the mediator, auth pipeline,
                           problem-details middleware, OpenAPI

CivicsPrep.Contracts       request/response types shared by the API and the
                           Blazor client, so the two cannot drift apart
CivicsPrep.Web             Blazor WebAssembly site, a pure consumer of the API
```

**Why it is laid out this way.** The domain rules are the part that must not be
duplicated: the answer matcher and study-plan generator are ports of the ones in
the Flutter app, so a given answer is graded identically on the phone, on the
website, and through the API. Keeping them in `Domain` means neither the
database nor the web framework can quietly change how grading works.

### CQRS

Every operation is a `IRequest` handled by exactly one handler, dispatched
through MediatR. Two pipeline behaviours run around each one:

- `ValidationBehaviour` runs the FluentValidation validators, so a handler only
  ever sees valid input and every validation failure returns the same shape.
- `LoggingBehaviour` records what ran and how long it took.

Controllers do nothing but bind the request and send it, which keeps behaviour
testable without spinning up HTTP.

## Running it

### With Docker (SQL Server included)

```bash
cd backend
docker compose up --build
```

The API comes up on <http://localhost:5199>, migrates the database and seeds all
228 official questions plus the 51 states. Swagger is at `/swagger`.

### Without Docker

The API can run on SQLite, which needs no database server:

```bash
cd backend
ASPNETCORE_ENVIRONMENT=Development \
Database__Provider=Sqlite \
ConnectionStrings__DefaultConnection="Data Source=civicsprep.db" \
Jwt__SigningKey="a-development-signing-key-at-least-32-bytes" \
dotnet run --project src/CivicsPrep.Api
```

For SQL Server, leave `Database:Provider` at its default and point
`ConnectionStrings:DefaultConnection` at your server.

### The website

```bash
cd backend
dotnet run --project src/CivicsPrep.Web
```

Set the API address in `src/CivicsPrep.Web/wwwroot/appsettings.json`.

**Settings › My state** offers the same one-call fetch the app uses: it fills in
the governor and senators you have not typed yourself, and lists the state's
House members so you can click the one for your district.

## Configuration

| Setting | Purpose |
|---|---|
| `ConnectionStrings:DefaultConnection` | Database connection string. |
| `Database:Provider` | `SqlServer` (default) or `Sqlite` for local development. |
| `Database:AutoMigrate` | Migrate and seed on startup. Default `true`. |
| `Jwt:SigningKey` | **Required.** At least 32 bytes. The API refuses to start without it. |
| `Jwt:AccessTokenMinutes` / `Jwt:RefreshTokenDays` | Token lifetimes. |
| `Officials:*` | Default answers for the time-sensitive federal questions. |
| `Congress:ApiKey` | Optional. Enables the live Congress.gov lookup. |
| `Cors:AllowedOrigins` | Origins the Blazor client is served from. |

Never commit a real `Jwt:SigningKey`. Use user-secrets locally and your
platform's secret store in production.

## API

All endpoints are under `/api`. The question catalogue and the state list are
readable anonymously; everything user-specific needs a bearer token.

| Method | Route | Purpose |
|---|---|---|
| `POST` | `/api/auth/register` · `/login` · `/refresh` · `/logout` | Accounts and tokens |
| `GET` | `/api/auth/me` | The signed-in user |
| `GET` | `/api/questions` | Questions, filtered and searched |
| `GET` | `/api/questions/{number}` · `/sections` | One question · the USCIS sections |
| `GET` | `/api/progress` · `/history` | Progress summary · completed tests |
| `PUT` | `/api/progress/questions/{number}` | Mark known / starred |
| `POST` | `/api/progress/reset` | Clear "known" marks |
| `POST` | `/api/tests` | Start a mock test |
| `POST` | `/api/tests/{id}/answers` · `/answers/override` · `/complete` | Answer · self-grade · finish |
| `GET` | `/api/tests/{id}` · `/{id}/result` | Resume · review |
| `GET`/`POST`/`PUT`/`DELETE` | `/api/study-plan` | The user's study plan |
| `GET` | `/api/states` · `/api/states/{code}/congress` | States · live Congress lookup |
| `GET` | `/api/states/{code}/answers` | Every state answer at once: capital, governor, senators, House delegation |
| `GET`/`PUT` | `/api/states/me` | The user's state info |
| `GET`/`PUT` | `/api/settings` · `/settings/officials` | Test version · current officials |

### State answers in one call

`GET /api/states/{code}/answers` is what the app calls to fill in the
state-dependent questions. It returns:

- the **capital**, from the seeded state list;
- the **governor**, from the maintained `Governors` table, with the `asOf` date
  the table was last verified;
- the state's **senators** and its **full House delegation** with district
  numbers, from Congress.gov.

The House list is deliberately complete — only the applicant knows their
congressional district, so the client has them pick. The endpoint is anonymous:
state answers are not personal, and the app must work before anyone signs in.

If `Congress:ApiKey` is unset or Congress.gov is unreachable, the call still
succeeds with `congressAvailable: false` and a `congressNotice` explaining why;
the capital and governor come back regardless. D.C. returns no governor and no
members, which is the official answer for D.C. residents.

The seeded governor also answers the "who is the governor of your state" civics
question for a user who has only picked their state. A name they enter
themselves always wins over the table.

### Grading is the server's job

A mock test stores the accepted answers when it starts and grades every
submission server-side, so a client cannot mark its own answers correct.
Questions that depend on state info the user has not supplied are returned as
`selfGraded`, and the client offers a manual right/wrong instead.

## Data

The question set is **generated from the Flutter app's Dart data files** by
`tools/export_seed_data.py` into `src/CivicsPrep.Infrastructure/SeedData/`, and
embedded in the assembly. That keeps one source of truth for the official
content. Regenerate after editing the app's datasets:

```bash
python3 backend/tools/export_seed_data.py . backend/src/CivicsPrep.Infrastructure/SeedData
```

The exporter asserts the official structure (100, 128 and 128 questions, 20
starred questions each, a guidance note on every dynamic question) and fails
rather than writing bad data.

### Governors

`src/CivicsPrep.Infrastructure/SeedData/governors.json` is **maintained by
hand** — it is the one dataset with no upstream file to generate from. It holds
50 rows (no D.C.) with an `asOf` date for the whole file, and is seeded
idempotently into the `Governors` table: editing a name and redeploying updates
the row. Because it lives on the server, a governor who changes mid-election
cycle is a data fix, not an app release.

Governors change with elections; verify at
[uscis.gov/citizenship/testupdates](https://www.uscis.gov/citizenship/testupdates)
before an interview.

## Tests

```bash
cd backend
dotnet test
```

- **Domain** — the answer matcher and study-plan generator, mirroring the
  Flutter suite case for case so the two implementations cannot diverge.
- **Application** — seeding, asserting the database ends up holding exactly the
  official content.
- **API** — the real API through `WebApplicationFactory` against in-memory
  SQLite: auth, the full mock-test journey, study plans, progress and
  authorization boundaries.

## Notes

- **MediatR is pinned to 12.x**, the last Apache-2.0 line. Version 13 and later
  are commercially licensed.
- The API stores only a **hash** of each refresh token, and rotates it on use.
