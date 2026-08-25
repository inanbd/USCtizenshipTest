using CivicsPrep.Domain.Entities;
using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Domain.Services;

/// <summary>
/// Builds a dated study plan that spreads all of a test's questions across the days remaining
/// until the exam, inserting periodic review days. Mirrors the Flutter client's generator.
/// </summary>
public static class StudyPlanGenerator
{
    /// <summary>
    /// Generates the plan. <paramref name="questionNumbers"/> is the ordered set of questions to
    /// cover; <paramref name="from"/> defaults to today.
    /// </summary>
    public static StudyPlan Generate(
        string userId,
        TestVersion version,
        DateOnly testDate,
        IReadOnlyList<int> questionNumbers,
        bool seniorOnly = false,
        DateOnly? from = null)
    {
        var today = from ?? DateOnly.FromDateTime(DateTime.UtcNow);

        var totalDays = testDate.DayNumber - today.DayNumber + 1; // include today
        if (totalDays < 1) totalDays = 1;

        var plan = new StudyPlan
        {
            UserId = userId,
            Version = version,
            TestDate = testDate,
            SeniorOnly = seniorOnly,
        };

        if (totalDays == 1)
        {
            plan.Days.Add(NewDay(1, today, isReview: true, questionNumbers));
            return plan;
        }

        // Every 4th day and the final day are review days; day 1 never is.
        bool IsReview(int dayNumber) =>
            dayNumber != 1 && (dayNumber % 4 == 0 || dayNumber == totalDays);

        var learningDayNumbers = Enumerable.Range(1, totalDays).Where(d => !IsReview(d)).ToList();
        var chunks = Distribute(questionNumbers, learningDayNumbers.Count);

        var chunkByDay = new Dictionary<int, List<int>>();
        for (var i = 0; i < learningDayNumbers.Count; i++)
        {
            chunkByDay[learningDayNumbers[i]] = chunks[i];
        }

        var learnedSoFar = new List<int>();
        for (var d = 1; d <= totalDays; d++)
        {
            var date = today.AddDays(d - 1);
            var chunk = chunkByDay.TryGetValue(d, out var c) ? c : [];

            if (IsReview(d) || chunk.Count == 0)
            {
                plan.Days.Add(NewDay(d, date, isReview: true, [.. learnedSoFar]));
            }
            else
            {
                learnedSoFar.AddRange(chunk);
                plan.Days.Add(NewDay(d, date, isReview: false, chunk));
            }
        }

        return plan;
    }

    private static StudyPlanDay NewDay(
        int dayNumber, DateOnly date, bool isReview, IReadOnlyList<int> questionNumbers)
    {
        var day = new StudyPlanDay
        {
            DayNumber = dayNumber,
            Date = date,
            IsReviewDay = isReview,
        };
        for (var i = 0; i < questionNumbers.Count; i++)
        {
            day.Questions.Add(new StudyPlanDayQuestion
            {
                QuestionNumber = questionNumbers[i],
                Ordinal = i,
            });
        }
        return day;
    }

    /// <summary>Splits into near-equal contiguous chunks, front-loading the remainder.</summary>
    private static List<List<int>> Distribute(IReadOnlyList<int> ids, int buckets)
    {
        if (buckets <= 0) return [[.. ids]];

        var result = new List<List<int>>(buckets);
        for (var i = 0; i < buckets; i++) result.Add([]);
        if (ids.Count == 0) return result;

        var baseSize = ids.Count / buckets;
        var remainder = ids.Count % buckets;
        var index = 0;
        for (var b = 0; b < buckets; b++)
        {
            var take = baseSize + (b < remainder ? 1 : 0);
            for (var i = 0; i < take && index < ids.Count; i++)
            {
                result[b].Add(ids[index++]);
            }
        }
        return result;
    }
}
