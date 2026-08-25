using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.StudyPlans;
using CivicsPrep.Domain.Services;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.StudyPlans;

/// <summary>
/// Creates (or replaces) the user's study plan from their interview date. A user has one active
/// plan at a time, matching the app.
/// </summary>
public sealed record CreateStudyPlanCommand(
    DateOnly TestDate,
    TestVersionDto? Version,
    bool SeniorOnly = false) : IRequest<StudyPlanDto>;

public class CreateStudyPlanCommandValidator : AbstractValidator<CreateStudyPlanCommand>
{
    public CreateStudyPlanCommandValidator(IClock clock)
    {
        RuleFor(x => x.TestDate)
            .GreaterThanOrEqualTo(_ => clock.Today)
            .WithMessage("Pick a test date that is today or later.");

        RuleFor(x => x.TestDate)
            .LessThanOrEqualTo(_ => clock.Today.AddYears(2))
            .WithMessage("Pick a test date within the next two years.");
    }
}

public class CreateStudyPlanCommandHandler(
    IApplicationDbContext db, ICurrentUser currentUser, IClock clock)
    : IRequestHandler<CreateStudyPlanCommand, StudyPlanDto>
{
    public async Task<StudyPlanDto> Handle(CreateStudyPlanCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        var version = request.Version?.ToDomain() ?? profile?.TestVersion
            ?? Domain.Enums.TestVersion.V2008;

        var numbers = await db.Questions
            .AsNoTracking()
            .Where(q => q.Version == version && (!request.SeniorOnly || q.Senior))
            .OrderBy(q => q.Number)
            .Select(q => q.Number)
            .ToListAsync(ct);

        // One active plan per user: replace any existing one.
        var existing = await db.StudyPlans
            .Include(p => p.Days).ThenInclude(d => d.Questions)
            .Where(p => p.UserId == userId)
            .ToListAsync(ct);
        if (existing.Count > 0) db.StudyPlans.RemoveRange(existing);

        var plan = StudyPlanGenerator.Generate(
            userId, version, request.TestDate, numbers, request.SeniorOnly, clock.Today);

        db.StudyPlans.Add(plan);
        await db.SaveChangesAsync(ct);

        return StudyPlanProjection.ToDto(plan);
    }
}
