using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Tests;
using CivicsPrep.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Tests;

/// <summary>
/// Finishes a test and returns the result. Correctly-answered questions are also marked known,
/// matching the app's behaviour.
/// </summary>
public sealed record CompleteTestCommand(Guid SessionId) : IRequest<TestResultDto>;

public class CompleteTestCommandHandler(
    IApplicationDbContext db, ICurrentUser currentUser, IClock clock)
    : IRequestHandler<CompleteTestCommand, TestResultDto>
{
    public async Task<TestResultDto> Handle(CompleteTestCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var session = await db.TestSessions
            .Include(s => s.Questions)
            .FirstOrDefaultAsync(s => s.Id == request.SessionId && s.UserId == userId, ct)
            ?? throw new NotFoundException("Test session was not found.");

        if (!session.IsComplete)
        {
            session.CompletedAt = clock.UtcNow;

            var correctNumbers = session.Questions
                .Where(q => q.IsCorrect)
                .Select(q => q.QuestionNumber)
                .Distinct()
                .ToList();

            if (correctNumbers.Count > 0)
            {
                var existing = await db.UserQuestionProgress
                    .Where(p => p.UserId == userId
                        && p.Version == session.Version
                        && correctNumbers.Contains(p.QuestionNumber))
                    .ToListAsync(ct);

                foreach (var number in correctNumbers)
                {
                    var row = existing.FirstOrDefault(p => p.QuestionNumber == number);
                    if (row is null)
                    {
                        db.UserQuestionProgress.Add(new UserQuestionProgress
                        {
                            UserId = userId,
                            Version = session.Version,
                            QuestionNumber = number,
                            IsLearned = true,
                            UpdatedAt = clock.UtcNow,
                        });
                    }
                    else
                    {
                        row.IsLearned = true;
                        row.UpdatedAt = clock.UtcNow;
                    }
                }
            }

            await db.SaveChangesAsync(ct);
        }

        return TestSessionProjection.ToResultDto(session);
    }
}
