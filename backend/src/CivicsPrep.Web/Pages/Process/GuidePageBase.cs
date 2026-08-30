using CivicsPrep.Contracts.Guide;
using CivicsPrep.Web.Services;
using Microsoft.AspNetCore.Components;

namespace CivicsPrep.Web.Pages.Process;

/// <summary>
/// Shared plumbing for the process pages: they all render one guide, fetched once and cached on
/// the API client, so moving between them costs nothing.
/// </summary>
public abstract class GuidePageBase : ComponentBase
{
    [Inject] protected CivicsApiClient Api { get; set; } = default!;

    protected NaturalizationGuideDto? Guide { get; private set; }
    protected string? Error { get; private set; }
    protected bool Loading { get; private set; } = true;

    protected override async Task OnInitializedAsync()
    {
        try
        {
            Guide = await Api.GetGuideAsync();
        }
        catch (ApiException ex)
        {
            Error = ex.Message;
        }
        finally
        {
            Loading = false;
        }
    }

    /// <summary>The guide's step with this key, or null if the content dropped it.</summary>
    protected GuideStepDto? Step(string key) =>
        Guide?.Steps.FirstOrDefault(s => s.Key == key);
}
