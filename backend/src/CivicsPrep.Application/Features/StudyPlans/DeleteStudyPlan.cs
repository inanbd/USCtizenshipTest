using CivicsPrep.Application.Common.Interfaces;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.StudyPlans;

/// <summary>Clears the user's study plan.</summary>
public sealed record DeleteStudyPlanCommand : IRequest<Unit>;

public class DeleteStudyPlanCommandHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<DeleteStudyPlanCommand, Unit>
{
    public async Task<Unit> Handle(DeleteStudyPlanCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var plans = await db.StudyPlans
            .Include(p => p.Days).ThenInclude(d => d.Questions)
            .Where(p => p.UserId == userId)
            .ToListAsync(ct);

        if (plans.Count > 0)
        {
            db.StudyPlans.RemoveRange(plans);
            await db.SaveChangesAsync(ct);
        }

        return Unit.Value;
    }
}
