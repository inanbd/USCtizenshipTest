using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.States;
using FluentValidation;
using MediatR;

namespace CivicsPrep.Application.Features.States;

/// <summary>
/// Live lookup of a state's senators and representatives. The backend owns this call - clients
/// never talk to Congress.gov directly, so the API key stays server-side and results are cached.
/// </summary>
public sealed record LookupCongressMembersQuery(string StateCode)
    : IRequest<IReadOnlyList<CongressMemberDto>>;

public class LookupCongressMembersQueryValidator : AbstractValidator<LookupCongressMembersQuery>
{
    public LookupCongressMembersQueryValidator()
    {
        RuleFor(x => x.StateCode).NotEmpty().Length(2);
    }
}

public class LookupCongressMembersQueryHandler(ICongressDirectory directory)
    : IRequestHandler<LookupCongressMembersQuery, IReadOnlyList<CongressMemberDto>>
{
    public Task<IReadOnlyList<CongressMemberDto>> Handle(
        LookupCongressMembersQuery request, CancellationToken ct) =>
        directory.GetMembersAsync(request.StateCode.Trim().ToUpperInvariant(), ct);
}
