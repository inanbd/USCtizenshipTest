using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Domain.Entities;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Profile;

/// <summary>The user's app settings that the server owns (currently the chosen test version).</summary>
public sealed record UserSettingsDto(TestVersionDto TestVersion);

public sealed record GetUserSettingsQuery : IRequest<UserSettingsDto>;

public class GetUserSettingsQueryHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<GetUserSettingsQuery, UserSettingsDto>
{
    public async Task<UserSettingsDto> Handle(GetUserSettingsQuery request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();
        var profile = await db.UserProfiles.AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId, ct);

        return new UserSettingsDto(
            (profile?.TestVersion ?? Domain.Enums.TestVersion.V2008).ToDto());
    }
}

public sealed record UpdateUserSettingsCommand(TestVersionDto TestVersion)
    : IRequest<UserSettingsDto>;

public class UpdateUserSettingsCommandHandler(
    IApplicationDbContext db, ICurrentUser currentUser, IClock clock)
    : IRequestHandler<UpdateUserSettingsCommand, UserSettingsDto>
{
    public async Task<UserSettingsDto> Handle(
        UpdateUserSettingsCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        if (profile is null)
        {
            profile = new UserProfile { UserId = userId };
            db.UserProfiles.Add(profile);
        }

        profile.TestVersion = request.TestVersion.ToDomain();
        profile.UpdatedAt = clock.UtcNow;

        await db.SaveChangesAsync(ct);
        return new UserSettingsDto(profile.TestVersion.ToDto());
    }
}
