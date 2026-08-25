using System.Net;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.StudyPlans;

namespace CivicsPrep.Api.Tests;

public class StudyPlanEndpointTests(CivicsPrepApiFactory factory)
    : IClassFixture<CivicsPrepApiFactory>
{
    private ApiClient NewClient() => new(factory.CreateClient());
    private static DateOnly Today => DateOnly.FromDateTime(DateTime.UtcNow);

    [Fact]
    public async Task No_plan_yet_returns_no_content()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var response = await client.Http.GetAsync("/api/study-plan");
        Assert.Equal(HttpStatusCode.NoContent, response.StatusCode);
    }

    [Fact]
    public async Task Creates_a_plan_covering_every_question()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var plan = await client.PostForAsync<StudyPlanDto, CreateStudyPlanRequest>(
            "/api/study-plan",
            new CreateStudyPlanRequest(Today.AddDays(14), TestVersionDto.V2008, false));

        Assert.Equal(15, plan.TotalDays);          // today through the test date
        Assert.Equal(0, plan.CompletedCount);
        Assert.Equal(Today, plan.Days[0].Date);

        var taught = plan.Days.Where(d => !d.IsReviewDay)
            .SelectMany(d => d.QuestionNumbers).ToList();
        Assert.Equal(100, taught.Count);
        Assert.Equal(100, taught.Distinct().Count());
    }

    [Fact]
    public async Task A_65_20_plan_only_schedules_the_starred_questions()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var plan = await client.PostForAsync<StudyPlanDto, CreateStudyPlanRequest>(
            "/api/study-plan",
            new CreateStudyPlanRequest(Today.AddDays(6), TestVersionDto.V2020, true));

        var taught = plan.Days.Where(d => !d.IsReviewDay)
            .SelectMany(d => d.QuestionNumbers).Distinct().ToList();
        Assert.Equal(20, taught.Count);
    }

    [Fact]
    public async Task Ticking_a_day_off_updates_progress_and_persists()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();
        await client.PostAsync("/api/study-plan",
            new CreateStudyPlanRequest(Today.AddDays(9), TestVersionDto.V2008, false));

        var updated = await client.PutForAsync<StudyPlanDto, SetDayCompleteRequest>(
            "/api/study-plan/days/1", new SetDayCompleteRequest(true));
        Assert.Equal(1, updated.CompletedCount);

        var reloaded = await client.GetAsync<StudyPlanDto>("/api/study-plan");
        Assert.Equal(1, reloaded.CompletedCount);
        Assert.True(reloaded.Days[0].IsComplete);
    }

    [Fact]
    public async Task Creating_a_plan_replaces_the_previous_one()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        await client.PostAsync("/api/study-plan",
            new CreateStudyPlanRequest(Today.AddDays(5), TestVersionDto.V2008, false));
        var second = await client.PostForAsync<StudyPlanDto, CreateStudyPlanRequest>(
            "/api/study-plan",
            new CreateStudyPlanRequest(Today.AddDays(20), TestVersionDto.V2008, false));

        var current = await client.GetAsync<StudyPlanDto>("/api/study-plan");
        Assert.Equal(second.Id, current.Id);
        Assert.Equal(21, current.TotalDays);
    }

    [Fact]
    public async Task A_plan_can_be_deleted()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();
        await client.PostAsync("/api/study-plan",
            new CreateStudyPlanRequest(Today.AddDays(5), TestVersionDto.V2008, false));

        var delete = await client.Http.DeleteAsync("/api/study-plan");
        Assert.Equal(HttpStatusCode.NoContent, delete.StatusCode);

        var after = await client.Http.GetAsync("/api/study-plan");
        Assert.Equal(HttpStatusCode.NoContent, after.StatusCode);
    }

    [Fact]
    public async Task A_test_date_in_the_past_is_rejected_with_a_helpful_message()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var response = await client.PostAsync("/api/study-plan",
            new CreateStudyPlanRequest(Today.AddDays(-1), TestVersionDto.V2008, false));

        Assert.Equal(HttpStatusCode.BadRequest, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("today or later", body);
    }

    [Fact]
    public async Task Study_plans_require_authentication()
    {
        var response = await NewClient().Http.GetAsync("/api/study-plan");
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }
}
