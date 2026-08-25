using System.Net;
using System.Net.Http.Json;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Progress;
using CivicsPrep.Contracts.States;
using CivicsPrep.Contracts.Tests;

namespace CivicsPrep.Api.Tests;

/// <summary>
/// The mock test is the feature where the server owns grading, so these walk the whole journey:
/// start, answer, override, complete, review.
/// </summary>
public class MockTestFlowTests(CivicsPrepApiFactory factory) : IClassFixture<CivicsPrepApiFactory>
{
    private ApiClient NewClient() => new(factory.CreateClient());

    private static StartTestRequest OneQuestion => new(TestVersionDto.V2008, TestSourceDto.All, 1);

    [Fact]
    public async Task Starting_a_test_returns_questions_without_their_answers()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", new StartTestRequest(TestVersionDto.V2008, TestSourceDto.All, null));

        Assert.Equal(10, session.Total);          // the official 2008 length
        Assert.Equal(6, session.PassMark);
        Assert.Equal(10, session.Questions.Count);
        Assert.All(session.Questions, q => Assert.False(string.IsNullOrWhiteSpace(q.Prompt)));
        // The DTO deliberately carries no accepted answers.
        Assert.DoesNotContain(session.Questions, q => q.Prompt.Contains("Constitution\n"));
    }

    [Fact]
    public async Task Grades_a_correct_answer_and_completes_as_passed()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", OneQuestion);

        // The deterministic shuffler serves question 1: the supreme law of the land.
        var feedback = await client.PostForAsync<AnswerFeedbackDto, SubmitAnswerRequest>(
            $"/api/tests/{session.Id}/answers", new SubmitAnswerRequest(0, "the constitution"));

        Assert.True(feedback.Correct);
        Assert.False(feedback.SelfGraded);
        Assert.True(feedback.IsFinalQuestion);
        Assert.Contains("the Constitution", feedback.AcceptedAnswers);

        var result = await client.PostForAsync<TestResultDto, object>(
            $"/api/tests/{session.Id}/complete", new { });

        Assert.Equal(1, result.Total);
        Assert.Equal(1, result.CorrectCount);
        Assert.Equal(1, result.PassMark);   // 60% of 1, rounded up
        Assert.True(result.Passed);
    }

    [Fact]
    public async Task Grades_a_wrong_answer_and_completes_as_failed()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", OneQuestion);

        var feedback = await client.PostForAsync<AnswerFeedbackDto, SubmitAnswerRequest>(
            $"/api/tests/{session.Id}/answers",
            new SubmitAnswerRequest(0, "the declaration of independence"));

        Assert.False(feedback.Correct);

        var result = await client.PostForAsync<TestResultDto, object>(
            $"/api/tests/{session.Id}/complete", new { });
        Assert.False(result.Passed);
    }

    [Fact]
    public async Task Rejects_the_vice_president_for_the_president_like_the_app_does()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        // Question 33 of the 2008 set: "Who signs bills to become laws?" -> the President.
        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", new StartTestRequest(TestVersionDto.V2008, TestSourceDto.All, 40));

        var ordinal = session.Questions.First(q => q.Number == 33).Ordinal;

        var wrong = await client.PostForAsync<AnswerFeedbackDto, SubmitAnswerRequest>(
            $"/api/tests/{session.Id}/answers",
            new SubmitAnswerRequest(ordinal, "the Vice President"));
        Assert.False(wrong.Correct);

        var right = await client.PostForAsync<AnswerFeedbackDto, SubmitAnswerRequest>(
            $"/api/tests/{session.Id}/answers",
            new SubmitAnswerRequest(ordinal, "the President"));
        Assert.True(right.Correct);
    }

    [Fact]
    public async Task A_state_question_is_self_graded_until_state_info_is_saved()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        // Question 44 of the 2008 set asks for the capital of your state.
        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", new StartTestRequest(TestVersionDto.V2008, TestSourceDto.All, 50));

        var q = session.Questions.First(x => x.Number == 44);
        Assert.True(q.SelfGraded);

        var feedback = await client.PostForAsync<AnswerFeedbackDto, SubmitAnswerRequest>(
            $"/api/tests/{session.Id}/answers", new SubmitAnswerRequest(q.Ordinal, "Austin"));

        Assert.True(feedback.SelfGraded);
        Assert.False(feedback.Correct);

        // The user can correct the grade themselves.
        var overridden = await client.PostForAsync<AnswerFeedbackDto, OverrideAnswerRequest>(
            $"/api/tests/{session.Id}/answers/override",
            new OverrideAnswerRequest(q.Ordinal, true));
        Assert.True(overridden.Correct);
    }

    [Fact]
    public async Task Saving_state_info_makes_the_capital_question_auto_gradeable()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        await client.PutForAsync<StateInfoDto, UpdateStateInfoRequest>(
            "/api/states/me", new UpdateStateInfoRequest("TX", "Jane Gov", "Sen One", "Sen Two", "Rep"));

        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", new StartTestRequest(TestVersionDto.V2008, TestSourceDto.All, 50));

        var q = session.Questions.First(x => x.Number == 44);
        Assert.False(q.SelfGraded);

        var feedback = await client.PostForAsync<AnswerFeedbackDto, SubmitAnswerRequest>(
            $"/api/tests/{session.Id}/answers", new SubmitAnswerRequest(q.Ordinal, "Austin"));

        Assert.True(feedback.Correct);
        Assert.Contains("Austin", feedback.AcceptedAnswers);
    }

    [Fact]
    public async Task Completing_a_test_marks_correct_answers_known_and_records_history()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", OneQuestion);
        await client.PostAsync($"/api/tests/{session.Id}/answers",
            new SubmitAnswerRequest(0, "the constitution"));
        await client.PostAsync($"/api/tests/{session.Id}/complete", new { });

        var progress = await client.GetAsync<ProgressSummaryDto>("/api/progress?version=V2008");
        Assert.Contains(1, progress.LearnedNumbers);
        Assert.NotNull(progress.LastResult);
        Assert.True(progress.LastResult!.Passed);

        var history = await client.GetAsync<IReadOnlyList<TestHistoryEntryDto>>(
            "/api/progress/history?version=V2008");
        Assert.Single(history);
    }

    [Fact]
    public async Task Answers_cannot_be_submitted_after_completion()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", OneQuestion);
        await client.PostAsync($"/api/tests/{session.Id}/answers",
            new SubmitAnswerRequest(0, "the constitution"));
        await client.PostAsync($"/api/tests/{session.Id}/complete", new { });

        var late = await client.PostAsync($"/api/tests/{session.Id}/answers",
            new SubmitAnswerRequest(0, "something else"));
        Assert.Equal(HttpStatusCode.Conflict, late.StatusCode);
    }

    [Fact]
    public async Task A_test_can_be_resumed_by_id()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var session = await client.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", new StartTestRequest(TestVersionDto.V2008, TestSourceDto.All, 3));
        await client.PostAsync($"/api/tests/{session.Id}/answers",
            new SubmitAnswerRequest(0, "the constitution"));

        var resumed = await client.GetAsync<TestSessionDto>($"/api/tests/{session.Id}");
        Assert.Equal(3, resumed.Total);
        Assert.Equal(1, resumed.AnsweredCount);
        Assert.Null(resumed.CompletedAt);
    }

    [Fact]
    public async Task One_users_test_is_not_visible_to_another()
    {
        var owner = NewClient();
        await owner.RegisterAndSignInAsync();
        var session = await owner.PostForAsync<TestSessionDto, StartTestRequest>(
            "/api/tests", OneQuestion);

        var stranger = NewClient();
        await stranger.RegisterAndSignInAsync();

        var response = await stranger.Http.GetAsync($"/api/tests/{session.Id}");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Starting_a_test_requires_authentication()
    {
        var response = await NewClient().PostAsync("/api/tests", OneQuestion);
        Assert.Equal(HttpStatusCode.Unauthorized, response.StatusCode);
    }

    [Fact]
    public async Task Starred_source_with_no_stars_is_rejected_clearly()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var response = await client.PostAsync(
            "/api/tests", new StartTestRequest(TestVersionDto.V2008, TestSourceDto.Starred, 5));

        Assert.Equal(HttpStatusCode.Conflict, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("Star some questions", body);
    }
}
