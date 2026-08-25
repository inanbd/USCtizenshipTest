using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.StudyPlans;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.StudyPlans;

/// <summary>Ticks a study day off (or un-ticks it).</summary>
public sealed record SetStudyDayCompleteCommand(int DayNumber, bool IsComplete)
    : IRequest<StudyPlanDto>;

public class SetStudyDayCompleteCommandHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<SetStudyDayCompleteCommand, StudyPlanDto>
{
    public async Task<StudyPlanDto> Handle(SetStudyDayCompleteCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var plan = await db.StudyPlans
            .Include(p => p.Days).ThenInclude(d => d.Questions)
            .Where(p => p.UserId == userId)
            .OrderByDescending(p => p.CreatedAt)
            .FirstOrDefaultAsync(ct)
            ?? throw new NotFoundException("You do not have a study plan yet.");

        var day = plan.Days.FirstOrDefault(d => d.DayNumber == request.DayNumber)
            ?? throw new NotFoundException($"Day {request.DayNumber} is not part of your plan.");

        day.IsComplete = request.IsComplete;
        await db.SaveChangesAsync(ct);

        return StudyPlanProjection.ToDto(plan);
    }
}
