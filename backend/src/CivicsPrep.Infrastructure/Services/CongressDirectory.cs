using System.Net;
using System.Text.Json;
using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.States;
using Microsoft.Extensions.Caching.Memory;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace CivicsPrep.Infrastructure.Services;

public class CongressOptions
{
    public const string SectionName = "Congress";

    /// <summary>Free key from https://api.congress.gov/sign-up/. Empty disables live lookup.</summary>
    public string ApiKey { get; set; } = "";

    public string BaseUrl { get; set; } = "https://api.congress.gov/v3";

    /// <summary>Congress membership changes rarely, so responses are cached.</summary>
    public int CacheHours { get; set; } = 12;
}

/// <summary>
/// Live lookup of a state's members of Congress. The backend owns this call so the API key never
/// reaches a client and every consumer shares one cache.
/// </summary>
public class CongressDirectory(
    HttpClient http,
    IOptions<CongressOptions> options,
    IMemoryCache cache,
    ILogger<CongressDirectory> logger) : ICongressDirectory
{
    private readonly CongressOptions _options = options.Value;

    public async Task<IReadOnlyList<CongressMemberDto>> GetMembersAsync(
        string stateCode, CancellationToken cancellationToken = default)
    {
        if (string.IsNullOrWhiteSpace(_options.ApiKey))
        {
            throw new ExternalServiceException(
                "Live lookup is not configured on this server. Set Congress:ApiKey to enable it, "
                + "or enter the names by hand.");
        }

        var cacheKey = $"congress:{stateCode}";
        if (cache.TryGetValue(cacheKey, out IReadOnlyList<CongressMemberDto>? cached) && cached is not null)
        {
            return cached;
        }

        var url = $"{_options.BaseUrl}/member/congress/current/{stateCode}"
            + $"?currentMember=true&limit=60&format=json&api_key={_options.ApiKey}";

        HttpResponseMessage response;
        try
        {
            response = await http.GetAsync(url, cancellationToken);
        }
        catch (Exception ex) when (ex is HttpRequestException or TaskCanceledException)
        {
            logger.LogWarning(ex, "Congress.gov request failed for {State}", stateCode);
            throw new ExternalServiceException("Could not reach Congress.gov. Try again shortly.");
        }

        if (response.StatusCode == HttpStatusCode.Forbidden)
        {
            throw new ExternalServiceException(
                "Congress.gov rejected the API key. Check the Congress:ApiKey setting.");
        }

        if (!response.IsSuccessStatusCode)
        {
            throw new ExternalServiceException(
                $"Congress.gov request failed ({(int)response.StatusCode}).");
        }

        var members = Parse(await response.Content.ReadAsStringAsync(cancellationToken));
        cache.Set(cacheKey, members, TimeSpan.FromHours(_options.CacheHours));
        return members;
    }

    private static List<CongressMemberDto> Parse(string json)
    {
        var result = new List<CongressMemberDto>();
        using var doc = JsonDocument.Parse(json);

        if (!doc.RootElement.TryGetProperty("members", out var members)
            || members.ValueKind != JsonValueKind.Array)
        {
            return result;
        }

        foreach (var m in members.EnumerateArray())
        {
            var name = m.TryGetProperty("name", out var n) ? n.GetString() ?? "" : "";
            if (string.IsNullOrWhiteSpace(name)) continue;

            // The v3 API nests the current chamber under terms.item[].
            var chamber = "";
            if (m.TryGetProperty("terms", out var terms)
                && terms.TryGetProperty("item", out var items)
                && items.ValueKind == JsonValueKind.Array
                && items.GetArrayLength() > 0)
            {
                var last = items.EnumerateArray().Last();
                if (last.TryGetProperty("chamber", out var c)) chamber = c.GetString() ?? "";
            }

            var district = m.TryGetProperty("district", out var d) && d.ValueKind != JsonValueKind.Null
                ? d.ToString()
                : null;
            var party = m.TryGetProperty("partyName", out var p) ? p.GetString() : null;

            result.Add(new CongressMemberDto(name, chamber, district, party));
        }

        return result;
    }
}
