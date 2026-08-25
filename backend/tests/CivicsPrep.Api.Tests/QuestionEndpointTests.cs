using System.Net;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Questions;

namespace CivicsPrep.Api.Tests;

public class QuestionEndpointTests(CivicsPrepApiFactory factory)
    : IClassFixture<CivicsPrepApiFactory>
{
    private ApiClient NewClient() => new(factory.CreateClient());

    [Fact]
    public async Task Serves_the_full_2008_set_anonymously()
    {
        var list = await NewClient().GetAsync<QuestionListDto>("/api/questions?version=V2008");

        Assert.Equal(100, list.Total);
        Assert.Equal(10, list.AskedCount);
        Assert.Equal(6, list.PassCount);
        Assert.Equal(TestVersionDto.V2008, list.Version);
    }

    [Fact]
    public async Task Serves_the_full_2020_set()
    {
        var list = await NewClient().GetAsync<QuestionListDto>("/api/questions?version=V2020");

        Assert.Equal(128, list.Total);
        Assert.Equal(20, list.AskedCount);
        Assert.Equal(12, list.PassCount);
    }

    [Theory]
    [InlineData("V2008")]
    [InlineData("V2020")]
    public async Task Each_version_has_exactly_twenty_65_20_questions(string version)
    {
        var list = await NewClient().GetAsync<QuestionListDto>(
            $"/api/questions?version={version}&filter=Senior");

        Assert.Equal(20, list.Total);
        Assert.All(list.Questions, q => Assert.True(q.Senior));
    }

    [Fact]
    public async Task Returns_official_content_for_a_known_question()
    {
        var q = await NewClient().GetAsync<QuestionDto>("/api/questions/1?version=V2008");

        Assert.Equal("What is the supreme law of the land?", q.Prompt);
        Assert.Contains("the Constitution", q.Answers);
        Assert.Equal("American Government", q.CategoryLabel);
    }

    [Fact]
    public async Task Unknown_question_numbers_are_404()
    {
        var response = await NewClient().Http.GetAsync("/api/questions/999?version=V2008");
        Assert.Equal(HttpStatusCode.NotFound, response.StatusCode);
    }

    [Fact]
    public async Task Searches_by_prompt_and_by_answer()
    {
        var client = NewClient();

        var byPrompt = await client.GetAsync<QuestionListDto>(
            "/api/questions?version=V2008&search=Statue of Liberty");
        Assert.Contains(byPrompt.Questions, q => q.Prompt.Contains("Statue of Liberty"));

        var byAnswer = await client.GetAsync<QuestionListDto>(
            "/api/questions?version=V2008&search=Woodrow");
        Assert.Contains(byAnswer.Questions, q => q.Prompt.Contains("World War I"));
    }

    [Fact]
    public async Task Search_with_no_matches_returns_an_empty_list()
    {
        var list = await NewClient().GetAsync<QuestionListDto>(
            "/api/questions?version=V2008&search=zzzznotaquestion");

        Assert.Equal(0, list.Total);
        Assert.Empty(list.Questions);
    }

    [Fact]
    public async Task Lists_the_uscis_sections_in_order()
    {
        var sections = await NewClient()
            .GetAsync<IReadOnlyList<SectionDto>>("/api/questions/sections?version=V2008");

        Assert.NotEmpty(sections);
        Assert.Equal("Principles of American Democracy", sections[0].Name);
        Assert.Equal(100, sections.Sum(s => s.QuestionCount));
    }

    [Fact]
    public async Task State_questions_are_flagged_as_needing_user_data()
    {
        // Question 44 of the 2008 set asks for the capital of your state.
        var q = await NewClient().GetAsync<QuestionDto>("/api/questions/44?version=V2008");

        Assert.True(q.IsStateDependent);
        Assert.True(q.NeedsUserData);
        Assert.NotNull(q.Note);
    }

    [Fact]
    public async Task Officeholder_questions_resolve_from_server_configuration()
    {
        // Question 28 of the 2008 set asks who the President is now.
        var q = await NewClient().GetAsync<QuestionDto>("/api/questions/28?version=V2008");

        Assert.True(q.IsTimeSensitive);
        Assert.Equal(["Test President"], q.Answers);
    }
}
