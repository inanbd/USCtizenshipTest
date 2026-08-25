using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Domain.Services;
using Microsoft.Extensions.Options;

namespace CivicsPrep.Infrastructure.Services;

public class SystemClock : IClock
{
    public DateTimeOffset UtcNow => DateTimeOffset.UtcNow;
}

/// <summary>
/// Server-configured answers for the time-sensitive federal questions, bound from the
/// "Officials" configuration section so they can be corrected without a code change.
/// </summary>
public class OfficialsOptions
{
    public const string SectionName = "Officials";

    public string President { get; set; } = "";
    public string VicePresident { get; set; } = "";
    public string Speaker { get; set; } = "";
    public string ChiefJustice { get; set; } = "";
    public string PresidentParty { get; set; } = "";
}

public class OfficialsProvider(IOptions<OfficialsOptions> options) : IOfficialsProvider
{
    public CurrentOfficials Defaults { get; } = new(
        options.Value.President,
        options.Value.VicePresident,
        options.Value.Speaker,
        options.Value.ChiefJustice,
        options.Value.PresidentParty);
}

/// <summary>Picks a random subset - the real behaviour for a mock test.</summary>
public class RandomQuestionShuffler : IQuestionShuffler
{
    public IReadOnlyList<T> Take<T>(IReadOnlyList<T> source, int count)
    {
        var copy = source.ToArray();
        Random.Shared.Shuffle(copy);
        return [.. copy.Take(Math.Min(count, copy.Length))];
    }
}
