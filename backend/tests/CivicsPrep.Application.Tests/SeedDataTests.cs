using CivicsPrep.Domain.Enums;
using CivicsPrep.Infrastructure.Persistence;
using CivicsPrep.Infrastructure.Persistence.Seeding;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Logging.Abstractions;

namespace CivicsPrep.Application.Tests;

/// <summary>
/// The seed data is generated from the Flutter app's Dart files, so these assert that the
/// database ends up holding exactly the official content - the same facts the app's own dataset
/// tests pin.
/// </summary>
public class SeedDataTests : IAsyncLifetime
{
    private SqliteConnection _connection = null!;
    private ApplicationDbContext _db = null!;

    public async Task InitializeAsync()
    {
        _connection = new SqliteConnection("DataSource=:memory:");
        await _connection.OpenAsync();

        var options = new DbContextOptionsBuilder<ApplicationDbContext>()
            .UseSqlite(_connection)
            .Options;

        _db = new ApplicationDbContext(options);
        await _db.Database.EnsureCreatedAsync();

        await new DatabaseSeeder(_db, NullLogger<DatabaseSeeder>.Instance).SeedAsync();
    }

    public async Task DisposeAsync()
    {
        await _db.DisposeAsync();
        await _connection.DisposeAsync();
    }

    [Theory]
    [InlineData(TestVersion.V2008, 100)]
    [InlineData(TestVersion.V2020, 128)]
    public async Task Seeds_the_right_number_of_questions(TestVersion version, int expected)
    {
        var count = await _db.Questions.CountAsync(q => q.Version == version);
        Assert.Equal(expected, count);
    }

    [Theory]
    [InlineData(TestVersion.V2008, 100)]
    [InlineData(TestVersion.V2020, 128)]
    public async Task Question_numbers_are_contiguous_from_one(TestVersion version, int expected)
    {
        var numbers = await _db.Questions.Where(q => q.Version == version)
            .Select(q => q.Number).OrderBy(n => n).ToListAsync();

        Assert.Equal(Enumerable.Range(1, expected), numbers);
    }

    [Theory]
    [InlineData(TestVersion.V2008)]
    [InlineData(TestVersion.V2020)]
    public async Task Each_version_marks_exactly_twenty_65_20_questions(TestVersion version)
    {
        var count = await _db.Questions.CountAsync(q => q.Version == version && q.Senior);
        Assert.Equal(20, count);
    }

    [Fact]
    public async Task Flags_the_official_state_dependent_questions()
    {
        var v2008 = await _db.Questions
            .Where(q => q.Version == TestVersion.V2008
                && (q.Kind == AnswerKind.StateCapital || q.Kind == AnswerKind.Governor
                    || q.Kind == AnswerKind.StateSenator || q.Kind == AnswerKind.StateRepresentative))
            .Select(q => q.Number).OrderBy(n => n).ToListAsync();
        Assert.Equal([20, 23, 43, 44], v2008);

        var v2020 = await _db.Questions
            .Where(q => q.Version == TestVersion.V2020
                && (q.Kind == AnswerKind.StateCapital || q.Kind == AnswerKind.Governor
                    || q.Kind == AnswerKind.StateSenator || q.Kind == AnswerKind.StateRepresentative))
            .Select(q => q.Number).OrderBy(n => n).ToListAsync();
        Assert.Equal([23, 29, 61, 62], v2020);
    }

    [Fact]
    public async Task Flags_the_official_time_sensitive_questions()
    {
        var v2008 = await _db.Questions
            .Where(q => q.Version == TestVersion.V2008
                && (q.Kind == AnswerKind.President || q.Kind == AnswerKind.VicePresident
                    || q.Kind == AnswerKind.Speaker || q.Kind == AnswerKind.ChiefJustice
                    || q.Kind == AnswerKind.PresidentParty))
            .Select(q => q.Number).OrderBy(n => n).ToListAsync();
        Assert.Equal([28, 29, 40, 46, 47], v2008);

        var v2020 = await _db.Questions
            .Where(q => q.Version == TestVersion.V2020
                && (q.Kind == AnswerKind.President || q.Kind == AnswerKind.VicePresident
                    || q.Kind == AnswerKind.Speaker || q.Kind == AnswerKind.ChiefJustice
                    || q.Kind == AnswerKind.PresidentParty))
            .Select(q => q.Number).OrderBy(n => n).ToListAsync();
        Assert.Equal([30, 38, 39, 57], v2020);
    }

    [Fact]
    public async Task Every_question_has_a_prompt_and_at_least_one_answer()
    {
        var questions = await _db.Questions.Include(q => q.Answers).ToListAsync();

        Assert.Equal(228, questions.Count);
        Assert.All(questions, q =>
        {
            Assert.False(string.IsNullOrWhiteSpace(q.Prompt));
            Assert.False(string.IsNullOrWhiteSpace(q.Section));
            Assert.NotEmpty(q.Answers);
        });
    }

    [Fact]
    public async Task Multi_answer_questions_list_enough_answers()
    {
        var questions = await _db.Questions.Include(q => q.Answers)
            .Where(q => q.RequiredCount > 1).ToListAsync();

        Assert.NotEmpty(questions);
        Assert.All(questions, q => Assert.True(q.Answers.Count >= q.RequiredCount,
            $"Q{q.Number} needs {q.RequiredCount} answers but lists {q.Answers.Count}"));
    }

    [Fact]
    public async Task Dynamic_questions_carry_guidance_notes()
    {
        var dynamicQuestions = await _db.Questions
            .Where(q => q.Kind != AnswerKind.Fixed).ToListAsync();

        Assert.All(dynamicQuestions, q => Assert.False(string.IsNullOrWhiteSpace(q.Note)));
    }

    [Fact]
    public async Task Seeds_all_fifty_states_plus_dc_with_correct_capitals()
    {
        var states = await _db.States.ToListAsync();

        Assert.Equal(51, states.Count);
        Assert.Equal("Sacramento", states.Single(s => s.Code == "CA").Capital);
        Assert.Equal("Albany", states.Single(s => s.Code == "NY").Capital);
        Assert.Equal("Juneau", states.Single(s => s.Code == "AK").Capital);
        Assert.Equal("Carson City", states.Single(s => s.Code == "NV").Capital);
    }

    [Fact]
    public async Task Seeding_twice_does_not_duplicate_anything()
    {
        await new DatabaseSeeder(_db, NullLogger<DatabaseSeeder>.Instance).SeedAsync();

        Assert.Equal(228, await _db.Questions.CountAsync());
        Assert.Equal(51, await _db.States.CountAsync());
        // Answers are replaced, not appended.
        Assert.Equal(1, await _db.Questions
            .Where(q => q.Version == TestVersion.V2008 && q.Number == 1)
            .Select(q => q.Answers.Count).SingleAsync());
    }
}
