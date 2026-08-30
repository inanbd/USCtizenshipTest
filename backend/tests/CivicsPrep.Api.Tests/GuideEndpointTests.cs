using System.Net;
using CivicsPrep.Contracts.Guide;

namespace CivicsPrep.Api.Tests;

public class GuideEndpointTests(CivicsPrepApiFactory factory)
    : IClassFixture<CivicsPrepApiFactory>
{
    private ApiClient NewClient() => new(factory.CreateClient());

    private Task<NaturalizationGuideDto> GetGuideAsync() =>
        NewClient().GetAsync<NaturalizationGuideDto>("/api/guide");

    [Fact]
    public async Task Serves_the_guide_without_an_account()
    {
        // Someone deciding whether to apply at all has not signed up yet.
        var response = await factory.CreateClient().GetAsync("/api/guide");

        Assert.Equal(HttpStatusCode.OK, response.StatusCode);
    }

    [Fact]
    public async Task Walks_the_journey_in_the_order_it_happens()
    {
        var guide = await GetGuideAsync();

        Assert.Equal(
            ["eligibility", "file", "receipt", "biometrics", "interview", "decision", "oath"],
            guide.Steps.Select(s => s.Key));

        Assert.All(guide.Steps, step =>
        {
            Assert.False(string.IsNullOrWhiteSpace(step.Title));
            Assert.False(string.IsNullOrWhiteSpace(step.Timing));
            Assert.False(string.IsNullOrWhiteSpace(step.Summary));
            Assert.NotEmpty(step.Details);
        });
    }

    [Fact]
    public async Task Says_how_long_the_whole_thing_takes()
    {
        var guide = await GetGuideAsync();

        Assert.InRange(guide.Timeline.TypicalLowMonths, 1, 24);
        Assert.True(guide.Timeline.TypicalHighMonths > guide.Timeline.TypicalLowMonths);
        Assert.False(string.IsNullOrWhiteSpace(guide.Timeline.Summary));
    }

    [Fact]
    public async Task Answers_how_to_apply_and_what_it_costs()
    {
        var guide = await GetGuideAsync();

        Assert.Contains(guide.Applying.Methods, m => m.Name == "Online");
        Assert.Contains(guide.Applying.Methods, m => m.Name == "By mail");
        Assert.All(guide.Applying.Methods, m => Assert.NotEmpty(m.Points));
        Assert.NotEmpty(guide.Applying.Checklist);

        Assert.Contains(guide.Costs.Items, c => c.Label.Contains("online") && c.Amount == "$710");
        Assert.Contains(guide.Costs.Items, c => c.Label.Contains("mail") && c.Amount == "$760");
        // The biometrics fee was folded into the filing fee; charging for it twice is a classic
        // stale-guide error.
        Assert.Contains(guide.Costs.Items, c => c.Label.Contains("Biometric") && c.Amount == "$0");
    }

    /// <summary>
    /// A proposed fee is not a real fee. If this ever reads as current, applicants would budget
    /// for the wrong number.
    /// </summary>
    [Fact]
    public async Task Marks_a_proposed_fee_change_as_not_in_effect()
    {
        var guide = await GetGuideAsync();

        if (guide.Costs.ProposedChange is { } proposed)
        {
            Assert.Contains("not in effect", proposed.Status, StringComparison.OrdinalIgnoreCase);
            Assert.False(string.IsNullOrWhiteSpace(proposed.Impact));
        }
    }

    [Fact]
    public async Task Explains_which_civics_set_the_filing_date_buys_you()
    {
        var guide = await GetGuideAsync();

        var variants = guide.Tests.Civics.Variants;
        Assert.Equal(["v2008", "v2025"], variants.Select(v => v.Version));
        Assert.Contains(variants, v => v.Detail.Contains("100") && v.Detail.Contains("6"));
        Assert.Contains(variants, v => v.Detail.Contains("128") && v.Detail.Contains("12"));

        Assert.Contains(guide.Tests.Exemptions, e => e.Label == "65/20");
        Assert.Contains("60", guide.Tests.Retake);
    }

    [Fact]
    public async Task Carries_a_review_date_and_only_secure_sources()
    {
        var guide = await GetGuideAsync();

        Assert.True(DateOnly.TryParse(guide.ReviewedOn, out _), "reviewedOn should be a date");
        Assert.NotEmpty(guide.Sources);
        Assert.All(guide.Sources, s => Assert.StartsWith("https://", s.Url));
        Assert.False(string.IsNullOrWhiteSpace(guide.Disclaimer));
    }
}
