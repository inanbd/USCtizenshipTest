using CivicsPrep.Contracts.States;
using CivicsPrep.Domain.Services;

namespace CivicsPrep.Application.Common.Interfaces;

/// <summary>Server-configured defaults for the time-sensitive federal answers.</summary>
public interface IOfficialsProvider
{
    CurrentOfficials Defaults { get; }
}

/// <summary>Live lookup of a state's members of Congress (Congress.gov).</summary>
public interface ICongressDirectory
{
    Task<IReadOnlyList<CongressMemberDto>> GetMembersAsync(
        string stateCode, CancellationToken cancellationToken = default);
}

/// <summary>Abstracts the clock so date-driven features (study plans) are testable.</summary>
public interface IClock
{
    DateTimeOffset UtcNow { get; }
    DateOnly Today => DateOnly.FromDateTime(UtcNow.UtcDateTime);
}

/// <summary>Chooses which questions a mock test draws, so tests can make it deterministic.</summary>
public interface IQuestionShuffler
{
    IReadOnlyList<T> Take<T>(IReadOnlyList<T> source, int count);
}
