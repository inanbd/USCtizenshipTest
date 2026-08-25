using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Tests;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Tests;

/// <summary>The full result of a completed test, including every answer for review.</summary>
public sealed record GetTestResultQuery(Guid SessionId) : IRequest<TestResultDto>;

public class GetTestResultQueryHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<GetTestResultQuery, TestResultDto>
{
    public async Task<TestResultDto> Handle(GetTestResultQuery request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var session = await db.TestSessions
            .AsNoTracking()
            .Include(s => s.Questions)
            .FirstOrDefaultAsync(s => s.Id == request.SessionId && s.UserId == userId, ct)
            ?? throw new NotFoundException("Test session was not found.");

        return TestSessionProjection.ToResultDto(session);
    }
}
