using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.States;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.States;

/// <summary>
/// Resolves every state-dependent civics answer for one state in a single call, so a client never
/// has to stitch three sources together (or hold a Congress.gov key of its own).
/// </summary>
public sealed record GetStateAnswersQuery(string StateCode) : IRequest<StateAnswersDto>;

public class GetStateAnswersQueryValidator : AbstractValidator<GetStateAnswersQuery>
{
    public GetStateAnswersQueryValidator()
    {
        RuleFor(x => x.StateCode).NotEmpty().Length(2);
    }
}

public class GetStateAnswersQueryHandler(IApplicationDbContext db, ICongressDirectory directory)
    : IRequestHandler<GetStateAnswersQuery, StateAnswersDto>
{
    public async Task<StateAnswersDto> Handle(GetStateAnswersQuery request, CancellationToken ct)
    {
        var code = request.StateCode.Trim().ToUpperInvariant();

        var state = await db.States.AsNoTracking().FirstOrDefaultAsync(s => s.Code == code, ct)
            ?? throw new NotFoundException($"No state with code '{code}'.");

        var governorRow = await db.Governors.AsNoTracking()
            .FirstOrDefaultAsync(g => g.StateCode == code, ct);

        var governor = governorRow is null
            ? null
            : new GovernorDto(governorRow.Name, governorRow.Since, governorRow.AsOf, governorRow.Source);

        // D.C. has no governor and no voting members of Congress, so there is nothing to look up -
        // the civics answers say exactly that.
        if (state.IsDistrictOfColumbia)
        {
            return new StateAnswersDto(
                state.Code, state.Name, state.Capital, true, null, [], [], false,
                "D.C. has no Governor and no U.S. Senators, and its Representative cannot vote.",
                DateTimeOffset.UtcNow);
        }

        // A missing or unreachable Congress.gov key must not fail the whole call: the capital and
        // governor are still worth returning, and the client lets the user type the rest.
        IReadOnlyList<CongressMemberDto> members = [];
        var available = true;
        string? notice = null;

        try
        {
            members = await directory.GetMembersAsync(code, ct);
        }
        catch (ExternalServiceException ex)
        {
            available = false;
            notice = ex.Message;
        }

        return new StateAnswersDto(
            state.Code,
            state.Name,
            state.Capital,
            false,
            governor,
            [.. members.Where(m => IsChamber(m, "senate")).OrderBy(m => m.Name)],
            [.. members.Where(m => IsChamber(m, "house")).OrderBy(DistrictOrder).ThenBy(m => m.Name)],
            available,
            notice,
            DateTimeOffset.UtcNow);
    }

    private static bool IsChamber(CongressMemberDto member, string chamber) =>
        member.Chamber.Contains(chamber, StringComparison.OrdinalIgnoreCase);

    /// <summary>Districts sort numerically ("2" before "10"); at-large seats have no number.</summary>
    private static int DistrictOrder(CongressMemberDto member) =>
        int.TryParse(member.District, out var n) ? n : int.MaxValue;
}
