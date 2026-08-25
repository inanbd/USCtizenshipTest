using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Tests;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Tests;

/// <summary>Re-reads an in-progress test, so a client can resume after a restart.</summary>
public sealed record GetTestSessionQuery(Guid SessionId) : IRequest<TestSessionDto>;

public class GetTestSessionQueryHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<GetTestSessionQuery, TestSessionDto>
{
    public async Task<TestSessionDto> Handle(GetTestSessionQuery request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var session = await db.TestSessions
            .AsNoTracking()
            .Include(s => s.Questions)
            .FirstOrDefaultAsync(s => s.Id == request.SessionId && s.UserId == userId, ct)
            ?? throw new NotFoundException("Test session was not found.");

        var catalogue = await db.Questions
            .AsNoTracking()
            .Where(q => q.Version == session.Version)
            .ToListAsync(ct);

        return TestSessionProjection.ToDto(session, catalogue);
    }
}
