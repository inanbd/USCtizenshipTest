using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.States;
using CivicsPrep.Domain.Entities;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.States;

/// <summary>Saves where the user lives and who represents them.</summary>
public sealed record UpdateStateInfoCommand(
    string StateCode,
    string? Governor,
    string? SenatorOne,
    string? SenatorTwo,
    string? Representative) : IRequest<StateInfoDto>;

public class UpdateStateInfoCommandValidator : AbstractValidator<UpdateStateInfoCommand>
{
    public UpdateStateInfoCommandValidator()
    {
        RuleFor(x => x.StateCode).NotEmpty().Length(2);
        RuleFor(x => x.Governor).MaximumLength(120);
        RuleFor(x => x.SenatorOne).MaximumLength(120);
        RuleFor(x => x.SenatorTwo).MaximumLength(120);
        RuleFor(x => x.Representative).MaximumLength(120);
    }
}

public class UpdateStateInfoCommandHandler(
    IApplicationDbContext db, ICurrentUser currentUser, IClock clock)
    : IRequestHandler<UpdateStateInfoCommand, StateInfoDto>
{
    public async Task<StateInfoDto> Handle(UpdateStateInfoCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();
        var code = request.StateCode.Trim().ToUpperInvariant();

        var state = await db.States.AsNoTracking().FirstOrDefaultAsync(s => s.Code == code, ct)
            ?? throw new NotFoundException($"'{request.StateCode}' is not a known state code.");

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        if (profile is null)
        {
            profile = new UserProfile { UserId = userId };
            db.UserProfiles.Add(profile);
        }

        profile.StateCode = code;
        profile.Governor = Clean(request.Governor);
        profile.SenatorOne = Clean(request.SenatorOne);
        profile.SenatorTwo = Clean(request.SenatorTwo);
        profile.Representative = Clean(request.Representative);
        profile.StateInfoUpdatedAt = clock.UtcNow;
        profile.UpdatedAt = clock.UtcNow;

        await db.SaveChangesAsync(ct);

        return new StateInfoDto(
            code, state.Name, state.Capital, profile.Governor,
            [.. profile.Senators], profile.Representative, profile.StateInfoUpdatedAt);

        static string? Clean(string? v) => string.IsNullOrWhiteSpace(v) ? null : v.Trim();
    }
}
