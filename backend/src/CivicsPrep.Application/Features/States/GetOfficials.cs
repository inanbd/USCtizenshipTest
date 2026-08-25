using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Features.Questions;
using CivicsPrep.Contracts.States;
using MediatR;

namespace CivicsPrep.Application.Features.States;

/// <summary>The effective answers to the time-sensitive federal questions for this user.</summary>
public sealed record GetOfficialsQuery : IRequest<OfficialsDto>;

public class GetOfficialsQueryHandler(UserContextLoader contextLoader)
    : IRequestHandler<GetOfficialsQuery, OfficialsDto>
{
    public async Task<OfficialsDto> Handle(GetOfficialsQuery request, CancellationToken ct)
    {
        var context = await contextLoader.LoadAsync(ct: ct);
        var o = context.Officials;
        return new OfficialsDto(o.President, o.VicePresident, o.Speaker, o.ChiefJustice, o.PresidentParty);
    }
}
