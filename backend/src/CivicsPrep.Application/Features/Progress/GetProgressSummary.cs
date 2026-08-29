using CivicsPrep.Domain.Enums;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Progress;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Progress;

/// <summary>The signed-in user's progress for a version, plus their most recent test result.</summary>
public sealed record GetProgressSummaryQuery(TestVersionDto? Version = null)
    : IRequest<ProgressSummaryDto>;

public class GetProgressSummaryQueryHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<GetProgressSummaryQuery, ProgressSummaryDto>
{
    public async Task<ProgressSummaryDto> Handle(GetProgressSummaryQuery request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        var version = request.Version?.ToDomain() ?? profile?.TestVersion
            ?? TestVersionExtensions.Current;

        var total = await db.Questions.CountAsync(q => q.Version == version, ct);

        var progress = await db.UserQuestionProgress
            .AsNoTracking()
            .Where(p => p.UserId == userId && p.Version == version)
            .ToListAsync(ct);

        var learned = progress.Where(p => p.IsLearned).Select(p => p.QuestionNumber).Order().ToList();
        var favorites = progress.Where(p => p.IsFavorite).Select(p => p.QuestionNumber).Order().ToList();

        var lastSession = await db.TestSessions
            .AsNoTracking()
            .Include(s => s.Questions)
            .Where(s => s.UserId == userId && s.Version == version && s.CompletedAt != null)
            .OrderByDescending(s => s.CompletedAt)
            .FirstOrDefaultAsync(ct);

        TestHistoryEntryDto? last = lastSession is null ? null : new TestHistoryEntryDto(
            lastSession.Id,
            lastSession.Version.ToDto(),
            lastSession.CompletedAt!.Value,
            lastSession.Total,
            lastSession.CorrectCount,
            lastSession.PassMark,
            lastSession.Passed,
            lastSession.Score);

        return new ProgressSummaryDto(
            version.ToDto(),
            total,
            learned.Count,
            favorites.Count,
            total == 0 ? 0 : (double)learned.Count / total,
            learned,
            favorites,
            last);
    }
}
