using CivicsPrep.Domain.Enums;
using CivicsPrep.Domain.Services;

namespace CivicsPrep.Domain.Tests;

public class StudyPlanGeneratorTests
{
    private static readonly DateOnly Today = new(2026, 3, 1);
    private static List<int> Numbers(int count) => [.. Enumerable.Range(1, count)];

    [Fact]
    public void TeachesEveryQuestionExactlyOnceAcrossLearningDays()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(20), Numbers(100), from: Today);

        var taught = plan.Days.Where(d => !d.IsReviewDay)
            .SelectMany(d => d.Questions.Select(q => q.QuestionNumber)).ToList();

        Assert.Equal(100, taught.Count);
        Assert.Equal(100, taught.Distinct().Count());
    }

    [Fact]
    public void RunsFromTodayThroughTheTestDateInclusive()
    {
        var testDate = Today.AddDays(9);
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, testDate, Numbers(100), from: Today);

        Assert.Equal(10, plan.Days.Count);
        Assert.Equal(Today, plan.Days[0].Date);
        Assert.Equal(testDate, plan.Days[^1].Date);
    }

    [Fact]
    public void NumbersDaysConsecutivelyWithConsecutiveDates()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(7), Numbers(100), from: Today);

        for (var i = 0; i < plan.Days.Count; i++)
        {
            Assert.Equal(i + 1, plan.Days[i].DayNumber);
            Assert.Equal(Today.AddDays(i), plan.Days[i].Date);
        }
    }

    [Fact]
    public void IncludesReviewDaysButNeverOnDayOne()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(11), Numbers(100), from: Today);

        Assert.Contains(plan.Days, d => d.IsReviewDay);
        Assert.False(plan.Days[0].IsReviewDay);
    }

    [Fact]
    public void EndsOnAReviewDayCoveringEverythingLearned()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(14), Numbers(100), from: Today);

        var last = plan.Days[^1];
        Assert.True(last.IsReviewDay);
        Assert.Equal(100, last.Questions.Count);
    }

    [Fact]
    public void ReviewDaysOnlyRevisitQuestionsAlreadyTaught()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(16), Numbers(100), from: Today);

        var taughtSoFar = new HashSet<int>();
        foreach (var day in plan.Days)
        {
            var numbers = day.Questions.Select(q => q.QuestionNumber).ToList();
            if (day.IsReviewDay)
            {
                Assert.True(numbers.All(taughtSoFar.Contains),
                    $"day {day.DayNumber} reviews unseen questions");
            }
            else
            {
                foreach (var n in numbers) taughtSoFar.Add(n);
            }
        }
    }

    [Fact]
    public void SpreadsQuestionsEvenlyAcrossLearningDays()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2020, Today.AddDays(30), Numbers(128), from: Today);

        var loads = plan.Days.Where(d => !d.IsReviewDay).Select(d => d.Questions.Count).ToList();
        Assert.NotEmpty(loads);
        Assert.True(loads.Max() - loads.Min() <= 1, "daily load should differ by at most one");
    }

    [Fact]
    public void ATestTodayProducesASingleCramDayWithEverything()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2020, Today, Numbers(128), from: Today);

        var day = Assert.Single(plan.Days);
        Assert.True(day.IsReviewDay);
        Assert.Equal(128, day.Questions.Count);
    }

    [Fact]
    public void APastTestDateStillYieldsAUsableOneDayPlan()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(-5), Numbers(100), from: Today);

        var day = Assert.Single(plan.Days);
        Assert.Equal(100, day.Questions.Count);
    }

    [Fact]
    public void ALongRunwayStillCoversEverythingWithoutEmptyLearningDays()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(300), Numbers(100), from: Today);

        foreach (var day in plan.Days.Where(d => !d.IsReviewDay))
        {
            Assert.NotEmpty(day.Questions);
        }
        var taught = plan.Days.Where(d => !d.IsReviewDay)
            .SelectMany(d => d.Questions.Select(q => q.QuestionNumber)).Distinct().Count();
        Assert.Equal(100, taught);
    }

    [Fact]
    public void StartsWithNoDaysCompleted()
    {
        var plan = StudyPlanGenerator.Generate(
            "u", TestVersion.V2008, Today.AddDays(5), Numbers(100), from: Today);

        Assert.Equal(0, plan.CompletedCount);
        Assert.Equal(0, plan.Progress);
    }
}

public class PassMarkTests
{
    [Theory]
    [InlineData(TestVersion.V2008, 10, 6)]
    [InlineData(TestVersion.V2020, 20, 12)]
    public void FullLengthTestsUseTheOfficialThreshold(TestVersion v, int total, int expected)
        => Assert.Equal(expected, v.PassMarkFor(total));

    [Theory]
    [InlineData(1, 1)]
    [InlineData(5, 3)]
    [InlineData(15, 9)]
    public void ShortenedTestsAreHeldToTheSameSixtyPercent(int total, int expected)
        => Assert.Equal(expected, TestVersion.V2008.PassMarkFor(total));

    [Fact]
    public void AnEmptyTestNeedsNothing()
        => Assert.Equal(0, TestVersion.V2008.PassMarkFor(0));
}
