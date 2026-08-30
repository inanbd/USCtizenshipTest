using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Guide;
using MediatR;

namespace CivicsPrep.Application.Features.Guide;

/// <summary>
/// The naturalization process guide. Public: someone deciding whether to apply at all has no
/// account yet, and this is exactly what they need to read first.
/// </summary>
public sealed record GetGuideQuery : IRequest<NaturalizationGuideDto>;

public class GetGuideQueryHandler(INaturalizationGuideProvider provider)
    : IRequestHandler<GetGuideQuery, NaturalizationGuideDto>
{
    public Task<NaturalizationGuideDto> Handle(GetGuideQuery request, CancellationToken ct) =>
        Task.FromResult(provider.Guide);
}
