using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.StudyPlans;
using CivicsPrep.Domain.Entities;

namespace CivicsPrep.Application.Features.StudyPlans;

public static class StudyPlanProjection
{
    public static StudyPlanDto ToDto(StudyPlan plan) => new(
        plan.Id,
        plan.Version.ToDto(),
        plan.TestDate,
        plan.SeniorOnly,
        plan.CreatedAt,
        plan.TotalDays,
        plan.CompletedCount,
        plan.Progress,
        [.. plan.Days.OrderBy(d => d.DayNumber).Select(d => new StudyPlanDayDto(
            d.DayNumber,
            d.Date,
            d.IsReviewDay,
            d.IsComplete,
            [.. d.Questions.OrderBy(q => q.Ordinal).Select(q => q.QuestionNumber)]))]);
}
