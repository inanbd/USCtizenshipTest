using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Features.Questions;
using CivicsPrep.Contracts.States;
using CivicsPrep.Domain.Entities;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.States;

/// <summary>
/// Overrides the current officeholders for this user. Blank values fall back to the
/// server-configured defaults.
/// </summary>
public sealed record UpdateOfficialsCommand(
    string? President,
    string? VicePresident,
    string? Speaker,
    string? ChiefJustice,
    string? PresidentParty) : IRequest<OfficialsDto>;

public class UpdateOfficialsCommandValidator : AbstractValidator<UpdateOfficialsCommand>
{
    public UpdateOfficialsCommandValidator()
    {
        RuleFor(x => x.President).MaximumLength(120);
        RuleFor(x => x.VicePresident).MaximumLength(120);
        RuleFor(x => x.Speaker).MaximumLength(120);
        RuleFor(x => x.ChiefJustice).MaximumLength(120);
        RuleFor(x => x.PresidentParty).MaximumLength(120);
    }
}

public class UpdateOfficialsCommandHandler(
    IApplicationDbContext db,
    ICurrentUser currentUser,
    UserContextLoader contextLoader,
    IClock clock) : IRequestHandler<UpdateOfficialsCommand, OfficialsDto>
{
    public async Task<OfficialsDto> Handle(UpdateOfficialsCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        if (profile is null)
        {
            profile = new UserProfile { UserId = userId };
            db.UserProfiles.Add(profile);
        }

        profile.President = Clean(request.President);
        profile.VicePresident = Clean(request.VicePresident);
        profile.Speaker = Clean(request.Speaker);
        profile.ChiefJustice = Clean(request.ChiefJustice);
        profile.PresidentParty = Clean(request.PresidentParty);
        profile.UpdatedAt = clock.UtcNow;

        await db.SaveChangesAsync(ct);

        var context = await contextLoader.LoadAsync(ct: ct);
        var o = context.Officials;
        return new OfficialsDto(o.President, o.VicePresident, o.Speaker, o.ChiefJustice, o.PresidentParty);

        static string? Clean(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
    }
}
