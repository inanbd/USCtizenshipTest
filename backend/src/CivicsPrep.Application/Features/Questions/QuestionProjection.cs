using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Questions;
using CivicsPrep.Domain.Entities;
using CivicsPrep.Domain.Services;

namespace CivicsPrep.Application.Features.Questions;

/// <summary>
/// Turns a domain question into the client-facing DTO, resolving the answers that depend on the
/// user's state or on current officeholders.
/// </summary>
public static class QuestionProjection
{
    public static QuestionDto ToDto(
        Question question,
        UserProfile? profile,
        UsState? state,
        CurrentOfficials officials,
        IReadOnlySet<int> learned,
        IReadOnlySet<int> favorites)
    {
        var resolved = AnswerResolver.Resolve(question, profile, state, officials);
        var needsUserData = AnswerResolver.NeedsUserData(question, profile, state, officials);

        // When a state answer is missing we still show the official placeholder so the client has
        // something to display, and flag it via NeedsUserData.
        var answers = resolved.Count > 0
            ? resolved
            : question.Answers.OrderBy(a => a.Ordinal).Select(a => a.Text).ToList();

        return new QuestionDto(
            Number: question.Number,
            Version: question.Version.ToDto(),
            Category: question.Category.ToDto(),
            CategoryLabel: question.Category.Label(),
            Section: question.Section,
            Prompt: question.Prompt,
            Answers: answers,
            Kind: question.Kind.ToDto(),
            Senior: question.Senior,
            RequiredCount: AnswerResolver.RequiredCountFor(question),
            Note: question.Note,
            IsStateDependent: question.IsStateDependent,
            IsTimeSensitive: question.IsTimeSensitive,
            NeedsUserData: needsUserData,
            IsLearned: learned.Contains(question.Number),
            IsFavorite: favorites.Contains(question.Number));
    }
}
