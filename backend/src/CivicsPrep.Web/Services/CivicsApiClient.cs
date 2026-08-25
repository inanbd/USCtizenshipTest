using System.Net;
using System.Net.Http.Json;
using System.Text.Json;
using System.Text.Json.Serialization;
using CivicsPrep.Application.Features.Profile;
using CivicsPrep.Contracts.Auth;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Progress;
using CivicsPrep.Contracts.Questions;
using CivicsPrep.Contracts.States;
using CivicsPrep.Contracts.StudyPlans;
using CivicsPrep.Contracts.Tests;

namespace CivicsPrep.Web.Services;

/// <summary>Raised when the API rejects a request, carrying the message it gave.</summary>
public class ApiException(string message, int statusCode) : Exception(message)
{
    public int StatusCode { get; } = statusCode;
}

/// <summary>
/// Typed client over the REST API. The website consumes exactly the same endpoints as the mobile
/// app, using the shared contract types, so the two cannot drift apart.
/// </summary>
public class CivicsApiClient(HttpClient http)
{
    private static readonly JsonSerializerOptions Json = CreateJsonOptions();

    private static JsonSerializerOptions CreateJsonOptions()
    {
        var options = new JsonSerializerOptions(JsonSerializerDefaults.Web);
        options.Converters.Add(new JsonStringEnumConverter());
        return options;
    }

    // --- auth ---
    public Task<AuthResponse> RegisterAsync(RegisterRequest request) =>
        PostAsync<AuthResponse, RegisterRequest>("api/auth/register", request);

    public Task<AuthResponse> LoginAsync(LoginRequest request) =>
        PostAsync<AuthResponse, LoginRequest>("api/auth/login", request);

    public Task LogoutAsync(string refreshToken) =>
        SendAsync(HttpMethod.Post, "api/auth/logout", new RefreshRequest(refreshToken));

    // --- questions ---
    public Task<QuestionListDto> GetQuestionsAsync(
        TestVersionDto? version = null, string? filter = null, string? search = null)
    {
        var query = new List<string>();
        if (version is not null) query.Add($"version={version}");
        if (!string.IsNullOrWhiteSpace(filter)) query.Add($"filter={filter}");
        if (!string.IsNullOrWhiteSpace(search)) query.Add($"search={Uri.EscapeDataString(search)}");
        var suffix = query.Count == 0 ? "" : "?" + string.Join('&', query);
        return GetAsync<QuestionListDto>($"api/questions{suffix}");
    }

    public Task<QuestionDto> GetQuestionAsync(int number, TestVersionDto? version = null) =>
        GetAsync<QuestionDto>($"api/questions/{number}{VersionQuery(version)}");

    // --- progress ---
    public Task<ProgressSummaryDto> GetProgressAsync(TestVersionDto? version = null) =>
        GetAsync<ProgressSummaryDto>($"api/progress{VersionQuery(version)}");

    public Task SetQuestionProgressAsync(
        int number, bool? isLearned, bool? isFavorite, TestVersionDto? version = null) =>
        SendAsync(HttpMethod.Put, $"api/progress/questions/{number}{VersionQuery(version)}",
            new SetQuestionProgressRequest(isLearned, isFavorite));

    public Task ResetProgressAsync(TestVersionDto? version = null) =>
        SendAsync(HttpMethod.Post, $"api/progress/reset{VersionQuery(version)}", new { });

    public Task<IReadOnlyList<TestHistoryEntryDto>> GetHistoryAsync(TestVersionDto? version = null) =>
        GetAsync<IReadOnlyList<TestHistoryEntryDto>>($"api/progress/history{VersionQuery(version)}");

    // --- mock tests ---
    public Task<TestSessionDto> StartTestAsync(StartTestRequest request) =>
        PostAsync<TestSessionDto, StartTestRequest>("api/tests", request);

    public Task<AnswerFeedbackDto> SubmitAnswerAsync(Guid sessionId, int ordinal, string? answer) =>
        PostAsync<AnswerFeedbackDto, SubmitAnswerRequest>(
            $"api/tests/{sessionId}/answers", new SubmitAnswerRequest(ordinal, answer));

    public Task<AnswerFeedbackDto> OverrideAnswerAsync(Guid sessionId, int ordinal, bool correct) =>
        PostAsync<AnswerFeedbackDto, OverrideAnswerRequest>(
            $"api/tests/{sessionId}/answers/override", new OverrideAnswerRequest(ordinal, correct));

    public Task<TestResultDto> CompleteTestAsync(Guid sessionId) =>
        PostAsync<TestResultDto, object>($"api/tests/{sessionId}/complete", new { });

    // --- study plan ---
    public async Task<StudyPlanDto?> GetStudyPlanAsync()
    {
        var response = await http.GetAsync("api/study-plan");
        if (response.StatusCode == HttpStatusCode.NoContent) return null;
        await EnsureSuccessAsync(response);
        return await response.Content.ReadFromJsonAsync<StudyPlanDto>(Json);
    }

    public Task<StudyPlanDto> CreateStudyPlanAsync(CreateStudyPlanRequest request) =>
        PostAsync<StudyPlanDto, CreateStudyPlanRequest>("api/study-plan", request);

    public Task<StudyPlanDto> SetDayCompleteAsync(int dayNumber, bool isComplete) =>
        PutAsync<StudyPlanDto, SetDayCompleteRequest>(
            $"api/study-plan/days/{dayNumber}", new SetDayCompleteRequest(isComplete));

    public Task DeleteStudyPlanAsync() =>
        SendAsync<object>(HttpMethod.Delete, "api/study-plan", null);

    // --- states and settings ---
    public Task<IReadOnlyList<StateDto>> GetStatesAsync() =>
        GetAsync<IReadOnlyList<StateDto>>("api/states");

    public Task<StateInfoDto> GetStateInfoAsync() => GetAsync<StateInfoDto>("api/states/me");

    public Task<StateInfoDto> UpdateStateInfoAsync(UpdateStateInfoRequest request) =>
        PutAsync<StateInfoDto, UpdateStateInfoRequest>("api/states/me", request);

    public Task<IReadOnlyList<CongressMemberDto>> LookupCongressAsync(string stateCode) =>
        GetAsync<IReadOnlyList<CongressMemberDto>>($"api/states/{stateCode}/congress");

    public Task<OfficialsDto> GetOfficialsAsync() => GetAsync<OfficialsDto>("api/settings/officials");

    public Task<OfficialsDto> UpdateOfficialsAsync(UpdateOfficialsRequest request) =>
        PutAsync<OfficialsDto, UpdateOfficialsRequest>("api/settings/officials", request);

    public Task<UserSettingsDto> GetSettingsAsync() => GetAsync<UserSettingsDto>("api/settings");

    public Task<UserSettingsDto> UpdateSettingsAsync(TestVersionDto version) =>
        PutAsync<UserSettingsDto, UpdateUserSettingsCommand>(
            "api/settings", new UpdateUserSettingsCommand(version));

    // --- plumbing ---
    private static string VersionQuery(TestVersionDto? version) =>
        version is null ? "" : $"?version={version}";

    private async Task<T> GetAsync<T>(string url)
    {
        var response = await http.GetAsync(url);
        await EnsureSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<T>(Json))!;
    }

    private async Task<TResult> PostAsync<TResult, TBody>(string url, TBody body)
    {
        var response = await http.PostAsJsonAsync(url, body, Json);
        await EnsureSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResult>(Json))!;
    }

    private async Task<TResult> PutAsync<TResult, TBody>(string url, TBody body)
    {
        var response = await http.PutAsJsonAsync(url, body, Json);
        await EnsureSuccessAsync(response);
        return (await response.Content.ReadFromJsonAsync<TResult>(Json))!;
    }

    private async Task SendAsync<TBody>(HttpMethod method, string url, TBody? body)
    {
        var request = new HttpRequestMessage(method, url);
        if (body is not null) request.Content = JsonContent.Create(body, options: Json);
        var response = await http.SendAsync(request);
        await EnsureSuccessAsync(response);
    }

    /// <summary>Turns the API's problem response into a message worth showing the user.</summary>
    private static async Task EnsureSuccessAsync(HttpResponseMessage response)
    {
        if (response.IsSuccessStatusCode) return;

        string message;
        try
        {
            var problem = await response.Content.ReadFromJsonAsync<ApiProblemDto>(Json);
            message = problem?.Errors is { Count: > 0 }
                ? string.Join(" ", problem.Errors.SelectMany(e => e.Value))
                : problem?.Detail ?? problem?.Title ?? response.ReasonPhrase ?? "Request failed.";
        }
        catch
        {
            message = response.ReasonPhrase ?? "Request failed.";
        }

        throw new ApiException(message, (int)response.StatusCode);
    }
}
