using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Tests;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Tests;

/// <summary>
/// Lets the user correct the automatic grade for one answer - needed for self-graded questions
/// and for the cases where an officer would have accepted a phrasing the matcher did not.
/// </summary>
public sealed record OverrideAnswerCommand(Guid SessionId, int Ordinal, bool Correct)
    : IRequest<AnswerFeedbackDto>;

public class OverrideAnswerCommandHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<OverrideAnswerCommand, AnswerFeedbackDto>
{
    public async Task<AnswerFeedbackDto> Handle(OverrideAnswerCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var session = await db.TestSessions
            .Include(s => s.Questions)
            .FirstOrDefaultAsync(s => s.Id == request.SessionId && s.UserId == userId, ct)
            ?? throw new NotFoundException("Test session was not found.");

        var item = session.Questions.FirstOrDefault(q => q.Ordinal == request.Ordinal)
            ?? throw new NotFoundException($"Question {request.Ordinal} is not part of this test.");

        if (item.AnsweredAt is null)
        {
            throw new ConflictException("Answer that question before changing its grade.");
        }

        item.IsCorrect = request.Correct;
        item.WasOverridden = true;

        await db.SaveChangesAsync(ct);

        var accepted = AcceptedAnswerCodec.Decode(item.AcceptedAnswers);
        return new AnswerFeedbackDto(
            item.Ordinal,
            item.IsCorrect,
            SelfGraded: accepted.Count == 0,
            accepted,
            [],
            null,
            session.CorrectCount,
            session.PassMark,
            session.Questions.All(q => q.AnsweredAt is not null));
    }
}
