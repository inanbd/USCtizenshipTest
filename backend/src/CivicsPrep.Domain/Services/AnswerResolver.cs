using CivicsPrep.Domain.Entities;
using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Domain.Services;

/// <summary>
/// Resolves the answers that depend on the user's state or on who currently holds office.
/// Fixed questions pass straight through. Mirrors the Flutter client's QuestionRepository so
/// grading agrees across every surface.
/// </summary>
public static class AnswerResolver
{
    /// <summary>
    /// The accepted answers to grade against. Empty means the user has not supplied the data
    /// yet, so the question cannot be auto-graded.
    /// </summary>
    public static IReadOnlyList<string> Resolve(
        Question question,
        UserProfile? profile,
        UsState? state,
        CurrentOfficials officials)
    {
        switch (question.Kind)
        {
            case AnswerKind.Fixed:
                return [.. question.Answers.OrderBy(a => a.Ordinal).Select(a => a.Text)];

            case AnswerKind.President:
            case AnswerKind.VicePresident:
            case AnswerKind.Speaker:
            case AnswerKind.ChiefJustice:
            case AnswerKind.PresidentParty:
                var official = OfficialFor(question.Kind, profile, officials);
                return string.IsNullOrWhiteSpace(official) ? [] : [official.Trim()];

            case AnswerKind.StateCapital:
                if (state is null) return [];
                return state.IsDistrictOfColumbia
                    ? ["D.C. is not a state and has no capital."]
                    : [state.Capital];

            case AnswerKind.Governor:
                if (state is null) return [];
                if (state.IsDistrictOfColumbia) return ["D.C. does not have a Governor."];
                return string.IsNullOrWhiteSpace(profile?.Governor) ? [] : [profile!.Governor!.Trim()];

            case AnswerKind.StateSenator:
                if (state is null) return [];
                if (state.IsDistrictOfColumbia) return ["D.C. has no U.S. Senators."];
                return profile is null ? [] : [.. profile.Senators];

            case AnswerKind.StateRepresentative:
                if (state is null) return [];
                return string.IsNullOrWhiteSpace(profile?.Representative)
                    ? []
                    : [profile!.Representative!.Trim()];

            default:
                return [.. question.Answers.OrderBy(a => a.Ordinal).Select(a => a.Text)];
        }
    }

    /// <summary>
    /// How many distinct answers are required, adjusted for what is actually available: a state
    /// has two senators but the question only needs one.
    /// </summary>
    public static int RequiredCountFor(Question question) =>
        question.Kind == AnswerKind.StateSenator ? 1 : question.RequiredCount;

    /// <summary>True when the user still needs to supply data before this can be graded.</summary>
    public static bool NeedsUserData(
        Question question, UserProfile? profile, UsState? state, CurrentOfficials officials) =>
        question.IsStateDependent && Resolve(question, profile, state, officials).Count == 0;

    private static string OfficialFor(
        AnswerKind kind, UserProfile? profile, CurrentOfficials defaults) => kind switch
    {
        AnswerKind.President => Pick(profile?.President, defaults.President),
        AnswerKind.VicePresident => Pick(profile?.VicePresident, defaults.VicePresident),
        AnswerKind.Speaker => Pick(profile?.Speaker, defaults.Speaker),
        AnswerKind.ChiefJustice => Pick(profile?.ChiefJustice, defaults.ChiefJustice),
        AnswerKind.PresidentParty => Pick(profile?.PresidentParty, defaults.PresidentParty),
        _ => string.Empty,
    };

    private static string Pick(string? userValue, string fallback) =>
        string.IsNullOrWhiteSpace(userValue) ? fallback : userValue;
}
