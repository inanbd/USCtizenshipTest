namespace CivicsPrep.Domain.Enums;

/// <summary>
/// How the accepted answer for a question is produced. Most questions have
/// <see cref="Fixed"/> answers that never change. Some depend on the applicant's state, and
/// some depend on who currently holds an office; those are resolved at request time.
/// </summary>
public enum AnswerKind
{
    Fixed = 0,

    // Time-sensitive federal officials (verify at uscis.gov/citizenship/testupdates).
    President = 1,
    VicePresident = 2,
    Speaker = 3,
    ChiefJustice = 4,
    PresidentParty = 5,

    // State-dependent answers, resolved from the user's saved state info.
    StateCapital = 10,
    Governor = 11,
    StateSenator = 12,
    StateRepresentative = 13,
}

public static class AnswerKindExtensions
{
    public static bool IsFixed(this AnswerKind kind) => kind == AnswerKind.Fixed;

    public static bool IsStateDependent(this AnswerKind kind) => kind
        is AnswerKind.StateCapital
        or AnswerKind.Governor
        or AnswerKind.StateSenator
        or AnswerKind.StateRepresentative;

    public static bool IsTimeSensitive(this AnswerKind kind) => kind
        is AnswerKind.President
        or AnswerKind.VicePresident
        or AnswerKind.Speaker
        or AnswerKind.ChiefJustice
        or AnswerKind.PresidentParty;

    public static bool IsDynamic(this AnswerKind kind) => !kind.IsFixed();
}
