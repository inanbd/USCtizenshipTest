using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Progress;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Progress;

/// <summary>The user's completed mock tests, newest first.</summary>
public sealed record GetTestHistoryQuery(TestVersionDto? Version = null, int Limit = 50)
    : IRequest<IReadOnlyList<TestHistoryEntryDto>>;

public class GetTestHistoryQueryHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<GetTestHistoryQuery, IReadOnlyList<TestHistoryEntryDto>>
{
    public async Task<IReadOnlyList<TestHistoryEntryDto>> Handle(
        GetTestHistoryQuery request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();
        var limit = Math.Clamp(request.Limit, 1, 200);

        var query = db.TestSessions
            .AsNoTracking()
            .Include(s => s.Questions)
            .Where(s => s.UserId == userId && s.CompletedAt != null);

        if (request.Version is not null)
        {
            var version = request.Version.Value.ToDomain();
            query = query.Where(s => s.Version == version);
        }

        var sessions = await query
            .OrderByDescending(s => s.CompletedAt)
            .Take(limit)
            .ToListAsync(ct);

        return [.. sessions.Select(s => new TestHistoryEntryDto(
            s.Id, s.Version.ToDto(), s.CompletedAt!.Value, s.Total, s.CorrectCount,
            s.PassMark, s.Passed, s.Score))];
    }
}
