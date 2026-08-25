using CivicsPrep.Application.Features.Profile;
using CivicsPrep.Application.Features.States;
using CivicsPrep.Contracts.States;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>User settings: chosen test version and the current officeholders.</summary>
[Authorize]
public class SettingsController : ApiControllerBase
{
    /// <summary>The user's app settings.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(UserSettingsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<UserSettingsDto>> Get() =>
        Ok(await Mediator.Send(new GetUserSettingsQuery()));

    /// <summary>Updates the user's app settings.</summary>
    [HttpPut]
    [ProducesResponseType(typeof(UserSettingsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<UserSettingsDto>> Update(UpdateUserSettingsCommand command) =>
        Ok(await Mediator.Send(command));

    /// <summary>The effective answers to the time-sensitive federal questions.</summary>
    [HttpGet("officials")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(OfficialsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<OfficialsDto>> GetOfficials() =>
        Ok(await Mediator.Send(new GetOfficialsQuery()));

    /// <summary>Overrides the current officeholders for this user.</summary>
    [HttpPut("officials")]
    [ProducesResponseType(typeof(OfficialsDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<OfficialsDto>> UpdateOfficials(UpdateOfficialsRequest request) =>
        Ok(await Mediator.Send(new UpdateOfficialsCommand(
            request.President, request.VicePresident, request.Speaker,
            request.ChiefJustice, request.PresidentParty)));
}
