using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Tests;
using CivicsPrep.Domain.Services;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Tests;

/// <summary>Submits and grades one answer. Grading happens here, never on the client.</summary>
public sealed record SubmitAnswerCommand(Guid SessionId, int Ordinal, string? Answer)
    : IRequest<AnswerFeedbackDto>;

public class SubmitAnswerCommandValidator : AbstractValidator<SubmitAnswerCommand>
{
    public SubmitAnswerCommandValidator()
    {
        RuleFor(x => x.Ordinal).GreaterThanOrEqualTo(0);
        RuleFor(x => x.Answer).MaximumLength(500);
    }
}

public class SubmitAnswerCommandHandler(
    IApplicationDbContext db, ICurrentUser currentUser, IClock clock)
    : IRequestHandler<SubmitAnswerCommand, AnswerFeedbackDto>
{
    public async Task<AnswerFeedbackDto> Handle(SubmitAnswerCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var session = await db.TestSessions
            .Include(s => s.Questions)
            .FirstOrDefaultAsync(s => s.Id == request.SessionId && s.UserId == userId, ct)
            ?? throw new NotFoundException("Test session was not found.");

        if (session.IsComplete)
        {
            throw new ConflictException("This test has already been submitted.");
        }

        var item = session.Questions.FirstOrDefault(q => q.Ordinal == request.Ordinal)
            ?? throw new NotFoundException(
                $"Question {request.Ordinal} is not part of this test.");

        var accepted = AcceptedAnswerCodec.Decode(item.AcceptedAnswers);
        var question = await db.Questions.AsNoTracking().FirstOrDefaultAsync(
            q => q.Version == session.Version && q.Number == item.QuestionNumber, ct);

        var requiredCount = question is null ? 1 : AnswerResolver.RequiredCountFor(question);

        // No accepted answers means the user has not supplied their state info, so the answer
        // cannot be graded automatically and the client offers self-grading instead.
        var selfGraded = accepted.Count == 0;
        var match = selfGraded
            ? new MatchResult(false, [])
            : AnswerMatcher.Evaluate(request.Answer, accepted, requiredCount);

        item.UserAnswer = request.Answer?.Trim();
        item.IsCorrect = match.Correct;
        item.WasOverridden = false;
        item.AnsweredAt = clock.UtcNow;

        await db.SaveChangesAsync(ct);

        var isFinal = session.Questions.All(q => q.AnsweredAt is not null);

        return new AnswerFeedbackDto(
            item.Ordinal,
            match.Correct,
            selfGraded,
            accepted.Count == 0
                ? (question?.Answers.OrderBy(a => a.Ordinal).Select(a => a.Text).ToList() ?? [])
                : accepted,
            match.MatchedAnswers,
            question?.Note,
            session.CorrectCount,
            session.PassMark,
            isFinal);
    }
}
