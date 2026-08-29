using System.Reflection;
using System.Text.Json;
using CivicsPrep.Domain.Entities;
using CivicsPrep.Domain.Enums;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging;

namespace CivicsPrep.Infrastructure.Persistence.Seeding;

/// <summary>
/// Loads the official question set and state list into the database. The JSON is generated from
/// the Flutter app's Dart data files, so app, API and website all serve identical content.
/// Seeding is idempotent: it inserts what is missing and updates what has changed.
/// </summary>
public class DatabaseSeeder(ApplicationDbContext db, ILogger<DatabaseSeeder> logger)
{
    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    public async Task SeedAsync(CancellationToken ct = default)
    {
        await SeedStatesAsync(ct);
        await SeedGovernorsAsync(ct);
        await SeedQuestionsAsync(ct);
    }

    private async Task SeedStatesAsync(CancellationToken ct)
    {
        var seed = Load<List<SeedState>>("states.json");
        if (seed is null) return;

        var existing = await db.States.ToDictionaryAsync(s => s.Code, ct);
        var added = 0;

        foreach (var s in seed)
        {
            if (existing.TryGetValue(s.Code, out var row))
            {
                row.Name = s.Name;
                row.Capital = s.Capital;
            }
            else
            {
                db.States.Add(new UsState { Code = s.Code, Name = s.Name, Capital = s.Capital });
                added++;
            }
        }

        await db.SaveChangesAsync(ct);
        logger.LogInformation("Seeded states: {Added} added, {Total} total", added, seed.Count);
    }

    private async Task SeedGovernorsAsync(CancellationToken ct)
    {
        var seed = Load<SeedGovernorFile>("governors.json");
        if (seed is null) return;

        var asOf = DateOnly.TryParse(seed.AsOf, out var parsed)
            ? parsed
            : DateOnly.FromDateTime(DateTime.UtcNow);

        var existing = await db.Governors.ToDictionaryAsync(g => g.StateCode, ct);
        var added = 0;

        foreach (var g in seed.Governors)
        {
            var since = DateOnly.TryParse(g.Since ?? string.Empty, out var s) ? s : (DateOnly?)null;

            if (existing.TryGetValue(g.StateCode, out var row))
            {
                row.Name = g.Name;
                row.Since = since;
                row.AsOf = asOf;
                row.Source = seed.Source;
            }
            else
            {
                db.Governors.Add(new Governor
                {
                    StateCode = g.StateCode,
                    Name = g.Name,
                    Since = since,
                    AsOf = asOf,
                    Source = seed.Source,
                });
                added++;
            }
        }

        await db.SaveChangesAsync(ct);
        logger.LogInformation(
            "Seeded governors: {Added} added, {Total} total (as of {AsOf})",
            added, seed.Governors.Count, asOf);
    }

    private async Task SeedQuestionsAsync(CancellationToken ct)
    {
        var seed = Load<List<SeedQuestion>>("questions.json");
        if (seed is null) return;

        var existing = await db.Questions
            .Include(q => q.Answers)
            .ToDictionaryAsync(q => (q.Version, q.Number), ct);

        var added = 0;
        foreach (var s in seed)
        {
            var version = ParseVersion(s.Version);
            var key = (version, s.Number);

            if (!existing.TryGetValue(key, out var question))
            {
                question = new Question { Version = version, Number = s.Number };
                db.Questions.Add(question);
                added++;
            }

            question.Category = ParseCategory(s.Category);
            question.Section = s.Section;
            question.Prompt = s.Prompt;
            question.Kind = ParseKind(s.Kind);
            question.Senior = s.Senior;
            question.RequiredCount = s.RequiredCount;
            question.Note = s.Note;

            // Answers are owned by the question; replace them wholesale so edits propagate.
            question.Answers.Clear();
            for (var i = 0; i < s.Answers.Count; i++)
            {
                question.Answers.Add(new QuestionAnswer { Text = s.Answers[i], Ordinal = i });
            }
        }

        await db.SaveChangesAsync(ct);
        logger.LogInformation("Seeded questions: {Added} added, {Total} total", added, seed.Count);
    }

    private static T? Load<T>(string fileName)
    {
        var assembly = Assembly.GetExecutingAssembly();
        var resource = assembly.GetManifestResourceNames()
            .FirstOrDefault(n => n.EndsWith(fileName, StringComparison.OrdinalIgnoreCase))
            ?? throw new InvalidOperationException(
                $"Embedded seed file '{fileName}' was not found. "
                + "Run backend/tools/export_seed_data.py to regenerate it.");

        using var stream = assembly.GetManifestResourceStream(resource)!;
        return JsonSerializer.Deserialize<T>(stream, JsonOptions);
    }

    private static TestVersion ParseVersion(string value) => value.ToUpperInvariant() switch
    {
        "V2008" => TestVersion.V2008,
        "V2020" => TestVersion.V2020,
        "V2025" => TestVersion.V2025,
        _ => throw new InvalidOperationException($"Unknown test version '{value}'."),
    };

    private static QuestionCategory ParseCategory(string value) => value.ToLowerInvariant() switch
    {
        "americangovernment" => QuestionCategory.AmericanGovernment,
        "americanhistory" => QuestionCategory.AmericanHistory,
        "integratedcivics" => QuestionCategory.IntegratedCivics,
        _ => throw new InvalidOperationException($"Unknown category '{value}'."),
    };

    private static AnswerKind ParseKind(string value) => value.ToLowerInvariant() switch
    {
        "fixed" => AnswerKind.Fixed,
        "president" => AnswerKind.President,
        "vicepresident" => AnswerKind.VicePresident,
        "speaker" => AnswerKind.Speaker,
        "chiefjustice" => AnswerKind.ChiefJustice,
        "presidentparty" => AnswerKind.PresidentParty,
        "statecapital" => AnswerKind.StateCapital,
        "governor" => AnswerKind.Governor,
        "statesenator" => AnswerKind.StateSenator,
        "staterepresentative" => AnswerKind.StateRepresentative,
        _ => throw new InvalidOperationException($"Unknown answer kind '{value}'."),
    };
}
