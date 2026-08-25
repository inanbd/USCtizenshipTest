using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.States;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.States;

/// <summary>The signed-in user's saved state-specific answers.</summary>
public sealed record GetStateInfoQuery : IRequest<StateInfoDto>;

public class GetStateInfoQueryHandler(IApplicationDbContext db, ICurrentUser currentUser)
    : IRequestHandler<GetStateInfoQuery, StateInfoDto>
{
    public async Task<StateInfoDto> Handle(GetStateInfoQuery request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();
        var profile = await db.UserProfiles.AsNoTracking()
            .FirstOrDefaultAsync(p => p.UserId == userId, ct);

        if (profile?.StateCode is null)
        {
            return new StateInfoDto(null, null, null, null, [], null, null);
        }

        var state = await db.States.AsNoTracking()
            .FirstOrDefaultAsync(s => s.Code == profile.StateCode, ct);

        return new StateInfoDto(
            profile.StateCode,
            state?.Name,
            state?.Capital,
            profile.Governor,
            [.. profile.Senators],
            profile.Representative,
            profile.StateInfoUpdatedAt);
    }
}
