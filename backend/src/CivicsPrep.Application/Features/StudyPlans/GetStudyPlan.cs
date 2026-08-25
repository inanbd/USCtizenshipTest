using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.StudyPlans;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.StudyPlans;

/// <summary>The user's current study plan, or null when they have not made one.</summary>
public sealed record GetStudyPlanQuery : IRequest<StudyPlanDto?>;

public class GetStudyPlanQueryHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<GetStudyPlanQuery, StudyPlanDto?>
{
    public async Task<StudyPlanDto?> Handle(GetStudyPlanQuery request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var plan = await db.StudyPlans
            .AsNoTracking()
            .Include(p => p.Days).ThenInclude(d => d.Questions)
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .FirstOrDefaultAsync(ct);

        return plan is null ? null : StudyPlanProjection.ToDto(plan);
    }
}
