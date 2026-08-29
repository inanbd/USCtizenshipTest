using System.Net;
using CivicsPrep.Application.Features.Profile;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Progress;
using CivicsPrep.Contracts.Questions;
using CivicsPrep.Contracts.States;

namespace CivicsPrep.Api.Tests;

public class SettingsAndStateEndpointTests(CivicsPrepApiFactory factory)
    : IClassFixture<CivicsPrepApiFactory>
{
    private ApiClient NewClient() => new(factory.CreateClient());

    [Fact]
    public async Task Lists_all_fifty_states_plus_dc()
    {
        var states = await NewClient().GetAsync<IReadOnlyList<StateDto>>("/api/states");

        Assert.Equal(51, states.Count);
        Assert.Equal("Sacramento", states.Single(s => s.Code == "CA").Capital);
        Assert.True(states.Single(s => s.Code == "DC").IsDistrictOfColumbia);
    }

    [Fact]
    public async Task Saves_and_returns_state_info()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var saved = await client.PutForAsync<StateInfoDto, UpdateStateInfoRequest>(
            "/api/states/me",
            new UpdateStateInfoRequest("tx", "Jane Gov", "Sen One", "Sen Two", "Rep Person"));

        Assert.Equal("TX", saved.StateCode);
        Assert.Equal("Austin", saved.Capital);
        Assert.Equal(["Sen One", "Sen Two"], saved.Senators);

        var reloaded = await client.GetAsync<StateInfoDto>("/api/states/me");
        Assert.Equal("Jane Gov", reloaded.Governor);
    }

    [Fact]
    public async Task Resolves_every_state_answer_in_one_public_call()
    {
        // No sign-in: the app must be able to refresh its state answers without an account.
        var answers = await NewClient().GetAsync<StateAnswersDto>("/api/states/NV/answers");

        Assert.Equal("NV", answers.StateCode);
        Assert.Equal("Nevada", answers.StateName);
        Assert.Equal("Carson City", answers.Capital);
        Assert.False(answers.IsDistrictOfColumbia);

        Assert.NotNull(answers.Governor);
        Assert.False(string.IsNullOrWhiteSpace(answers.Governor!.Name));
        Assert.NotEqual(default, answers.Governor.AsOf);

        // No Congress.gov key is configured for the tests, so the live half degrades to a
        // notice instead of failing the whole call.
        Assert.False(answers.CongressAvailable);
        Assert.False(string.IsNullOrWhiteSpace(answers.CongressNotice));
        Assert.Empty(answers.Senators);
        Assert.Empty(answers.Representatives);
    }

    [Fact]
    public async Task State_answers_accept_a_lowercase_code()
    {
        var answers = await NewClient().GetAsync<StateAnswersDto>("/api/states/ca/answers");

        Assert.Equal("CA", answers.StateCode);
        Assert.Equal("Sacramento", answers.Capital);
    }

    [Fact]
    public async Task State_answers_for_dc_say_there_is_nothing_to_look_up()
    {
        var answers = await NewClient().GetAsync<StateAnswersDto>("/api/states/DC/answers");

        Assert.True(answers.IsDistrictOfColumbia);
        Assert.Null(answers.Governor);
        Assert.Empty(answers.Senators);
        Assert.Contains("no Governor", answers.CongressNotice);
    }

    [Fact]
    public async Task State_answers_reject_an_unknown_state()
    {
        var response = await factory.CreateClient().GetAsync("/api/states/ZZ/answers");

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    /// <summary>
    /// The maintained governors table means a user who only picks their state still gets Q43
    /// graded, and a name they type themselves still wins over it.
    /// </summary>
    [Fact]
    public async Task Seeded_governor_answers_the_governor_question_until_the_user_overrides_it()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();
        await client.PutAsync("/api/states/me",
            new UpdateStateInfoRequest("NV", null, null, null, null));

        var seeded = await client.GetAsync<StateAnswersDto>("/api/states/NV/answers");
        var question = await client.GetAsync<QuestionDto>("/api/questions/43?version=V2008");

        Assert.False(question.NeedsUserData);
        Assert.Equal([seeded.Governor!.Name], question.Answers);

        await client.PutAsync("/api/states/me",
            new UpdateStateInfoRequest("NV", "Someone Else", null, null, null));

        var overridden = await client.GetAsync<QuestionDto>("/api/questions/43?version=V2008");
        Assert.Equal(["Someone Else"], overridden.Answers);
    }

    [Fact]
    public async Task An_unknown_state_code_is_rejected()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var response = await client.PutAsync("/api/states/me",
            new UpdateStateInfoRequest("ZZ", null, null, null, null));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Saved_state_resolves_the_capital_question()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();
        await client.PutAsync("/api/states/me",
            new UpdateStateInfoRequest("NV", null, null, null, null));

        var q = await client.GetAsync<QuestionDto>("/api/questions/44?version=V2008");

        Assert.False(q.NeedsUserData);
        Assert.Equal(["Carson City"], q.Answers);
    }

    [Fact]
    public async Task Dc_gets_the_official_not_a_state_answers()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();
        await client.PutAsync("/api/states/me",
            new UpdateStateInfoRequest("DC", null, null, null, null));

        var capital = await client.GetAsync<QuestionDto>("/api/questions/44?version=V2008");
        Assert.Contains("not a state", capital.Answers.Single());

        var governor = await client.GetAsync<QuestionDto>("/api/questions/43?version=V2008");
        Assert.Contains("does not have a Governor", governor.Answers.Single());
    }

    [Fact]
    public async Task Officials_default_to_server_configuration_and_can_be_overridden()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var defaults = await client.GetAsync<OfficialsDto>("/api/settings/officials");
        Assert.Equal("Test President", defaults.President);

        var updated = await client.PutForAsync<OfficialsDto, UpdateOfficialsRequest>(
            "/api/settings/officials",
            new UpdateOfficialsRequest("My President", null, null, null, null));

        Assert.Equal("My President", updated.President);
        // Blank fields keep falling back to the server defaults.
        Assert.Equal("Test Speaker", updated.Speaker);

        var q = await client.GetAsync<QuestionDto>("/api/questions/28?version=V2008");
        Assert.Equal(["My President"], q.Answers);
    }

    [Fact]
    public async Task Chosen_test_version_is_remembered_and_drives_defaults()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        await client.PutForAsync<UserSettingsDto, UpdateUserSettingsCommand>(
            "/api/settings", new UpdateUserSettingsCommand(TestVersionDto.V2020));

        var settings = await client.GetAsync<UserSettingsDto>("/api/settings");
        Assert.Equal(TestVersionDto.V2020, settings.TestVersion);

        // With no explicit version, the API now serves the 2020 set.
        var list = await client.GetAsync<QuestionListDto>("/api/questions");
        Assert.Equal(128, list.Total);
    }

    [Fact]
    public async Task Live_congress_lookup_explains_when_it_is_not_configured()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var response = await client.Http.GetAsync("/api/states/CA/congress");

        Assert.Equal(HttpStatusCode.BadGateway, response.StatusCode);
        var body = await response.Content.ReadAsStringAsync();
        Assert.Contains("not configured", body);
    }

    [Fact]
    public async Task Progress_can_be_marked_and_reset()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        await client.PutAsync("/api/progress/questions/5?version=V2008",
            new SetQuestionProgressRequest(true, true));

        var summary = await client.GetAsync<ProgressSummaryDto>("/api/progress?version=V2008");
        Assert.Equal(100, summary.Total);
        Assert.Contains(5, summary.LearnedNumbers);
        Assert.Contains(5, summary.FavoriteNumbers);

        await client.PostAsync("/api/progress/reset?version=V2008", new { });

        var afterReset = await client.GetAsync<ProgressSummaryDto>("/api/progress?version=V2008");
        Assert.Empty(afterReset.LearnedNumbers);
        // Reset clears "known" but keeps stars.
        Assert.Contains(5, afterReset.FavoriteNumbers);
    }

    [Fact]
    public async Task Marking_progress_on_an_unknown_question_is_404()
    {
        var client = NewClient();
        await client.RegisterAndSignInAsync();

        var response = await client.PutAsync("/api/progress/questions/999?version=V2008",
            new SetQuestionProgressRequest(true, null));

        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task One_users_progress_is_invisible_to_another()
    {
        var first = NewClient();
        await first.RegisterAndSignInAsync();
        await first.PutAsync("/api/progress/questions/7?version=V2008",
            new SetQuestionProgressRequest(true, null));

        var second = NewClient();
        await second.RegisterAndSignInAsync();
        var summary = await second.GetAsync<ProgressSummaryDto>("/api/progress?version=V2008");

        Assert.Empty(summary.LearnedNumbers);
    }
}
