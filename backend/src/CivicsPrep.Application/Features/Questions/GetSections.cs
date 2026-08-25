using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Questions;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Questions;

/// <summary>Lists the USCIS sections for a version, in official order, with question counts.</summary>
public sealed record GetSectionsQuery(TestVersionDto? Version = null)
    : IRequest<IReadOnlyList<SectionDto>>;

public class GetSectionsQueryHandler(IApplicationDbContext db, UserContextLoader contextLoader)
    : IRequestHandler<GetSectionsQuery, IReadOnlyList<SectionDto>>
{
    public async Task<IReadOnlyList<SectionDto>> Handle(GetSectionsQuery request, CancellationToken ct)
    {
        var context = await contextLoader.LoadAsync(request.Version?.ToDomain(), ct);
        var version = request.Version?.ToDomain() ?? context.PreferredVersion;

        var rows = await db.Questions
            .AsNoTracking()
            .Where(q => q.Version == version)
            .OrderBy(q => q.Number)
            .Select(q => new { q.Section, q.Category })
            .ToListAsync(ct);

        return [.. rows
            .GroupBy(r => new { r.Section, r.Category })
            .Select(g => new SectionDto(g.Key.Section, g.Key.Category.ToDto(), g.Count()))];
    }
}
