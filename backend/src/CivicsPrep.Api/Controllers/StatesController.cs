using CivicsPrep.Application.Features.States;
using CivicsPrep.Contracts.States;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>
/// State-specific answers. The backend owns the Congress.gov call, so the API key stays
/// server-side and every client shares one cache.
/// </summary>
public class StatesController : ApiControllerBase
{
    /// <summary>All 50 states plus D.C., with their capitals.</summary>
    [HttpGet]
    [AllowAnonymous]
    [ProducesResponseType(typeof(IReadOnlyList<StateDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<StateDto>>> List() =>
        Ok(await Mediator.Send(new GetStatesQuery()));

    /// <summary>The signed-in user's saved state info.</summary>
    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType(typeof(StateInfoDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<StateInfoDto>> GetMine() =>
        Ok(await Mediator.Send(new GetStateInfoQuery()));

    /// <summary>Saves where the user lives and who represents them.</summary>
    [HttpPut("me")]
    [Authorize]
    [ProducesResponseType(typeof(StateInfoDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<StateInfoDto>> UpdateMine(UpdateStateInfoRequest request) =>
        Ok(await Mediator.Send(new UpdateStateInfoCommand(
            request.StateCode, request.Governor, request.SenatorOne,
            request.SenatorTwo, request.Representative)));

    /// <summary>
    /// Every state-dependent civics answer for one state: capital, governor, senators and the
    /// full House delegation to pick a representative from. Public, so the app can refresh
    /// without an account.
    /// </summary>
    [HttpGet("{stateCode}/answers")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(StateAnswersDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<StateAnswersDto>> Answers(string stateCode) =>
        Ok(await Mediator.Send(new GetStateAnswersQuery(stateCode)));

    /// <summary>Live lookup of a state's members of Congress.</summary>
    [HttpGet("{stateCode}/congress")]
    [Authorize]
    [ProducesResponseType(typeof(IReadOnlyList<CongressMemberDto>), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status502BadGateway)]
    public async Task<ActionResult<IReadOnlyList<CongressMemberDto>>> Congress(string stateCode) =>
        Ok(await Mediator.Send(new LookupCongressMembersQuery(stateCode)));
}
