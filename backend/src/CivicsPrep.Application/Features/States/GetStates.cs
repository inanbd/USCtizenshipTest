using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.States;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.States;

/// <summary>All 50 states plus D.C., with their capitals. Public - no sign-in needed.</summary>
public sealed record GetStatesQuery : IRequest<IReadOnlyList<StateDto>>;

public class GetStatesQueryHandler(IApplicationDbContext db)
    : IRequestHandler<GetStatesQuery, IReadOnlyList<StateDto>>
{
    public async Task<IReadOnlyList<StateDto>> Handle(GetStatesQuery request, CancellationToken ct)
    {
        var states = await db.States.AsNoTracking().OrderBy(s => s.Name).ToListAsync(ct);
        return [.. states.Select(s => new StateDto(s.Code, s.Name, s.Capital, s.IsDistrictOfColumbia))];
    }
}
