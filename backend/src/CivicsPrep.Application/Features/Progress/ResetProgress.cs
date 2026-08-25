using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Progress;

/// <summary>Clears the "known" marks for one version, leaving stars and history intact.</summary>
public sealed record ResetProgressCommand(TestVersionDto? Version) : IRequest<Unit>;

public class ResetProgressCommandHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<ResetProgressCommand, Unit>
{
    public async Task<Unit> Handle(ResetProgressCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();
        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        var version = request.Version?.ToDomain() ?? profile?.TestVersion
            ?? Domain.Enums.TestVersion.V2008;

        var rows = await db.UserQuestionProgress
            .Where(p => p.UserId == userId && p.Version == version && p.IsLearned)
            .ToListAsync(ct);

        foreach (var row in rows) row.IsLearned = false;

        await db.SaveChangesAsync(ct);
        return Unit.Value;
    }
}
