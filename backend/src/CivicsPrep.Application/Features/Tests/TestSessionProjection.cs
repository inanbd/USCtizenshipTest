using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Tests;
using CivicsPrep.Domain.Entities;

namespace CivicsPrep.Application.Features.Tests;

public static class TestSessionProjection
{
    public static TestSessionDto ToDto(TestSession session, IReadOnlyList<Question> catalogue)
    {
        var byNumber = catalogue.ToDictionary(q => q.Number);

        var questions = session.Questions
            .OrderBy(q => q.Ordinal)
            .Select(q =>
            {
                byNumber.TryGetValue(q.QuestionNumber, out var source);
                return new TestQuestionDto(
                    q.Ordinal,
                    q.QuestionNumber,
                    q.Prompt,
                    source is null ? 1 : Domain.Services.AnswerResolver.RequiredCountFor(source),
                    source?.Note,
                    SelfGraded: AcceptedAnswerCodec.Decode(q.AcceptedAnswers).Count == 0);
            })
            .ToList();

        return new TestSessionDto(
            session.Id,
            session.Version.ToDto(),
            session.Source.ToDto(),
            session.StartedAt,
            session.CompletedAt,
            session.Total,
            session.AnsweredCount,
            session.CorrectCount,
            session.PassMark,
            session.Passed,
            session.Score,
            questions);
    }

    public static TestResultDto ToResultDto(TestSession session) => new(
        session.Id,
        session.Version.ToDto(),
        session.CompletedAt ?? session.StartedAt,
        session.Total,
        session.CorrectCount,
        session.PassMark,
        session.Passed,
        session.Score,
        [.. session.Questions.OrderBy(q => q.Ordinal).Select(q => new TestResultAnswerDto(
            q.Ordinal,
            q.QuestionNumber,
            q.Prompt,
            q.UserAnswer,
            AcceptedAnswerCodec.Decode(q.AcceptedAnswers),
            q.IsCorrect,
            q.WasOverridden))]);
}
