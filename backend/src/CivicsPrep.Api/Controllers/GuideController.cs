using CivicsPrep.Application.Features.Guide;
using CivicsPrep.Contracts.Guide;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>The naturalization process: steps, timings, how to apply and what it costs.</summary>
[AllowAnonymous]
public class GuideController : ApiControllerBase
{
    /// <summary>The whole guide in one call. Clients cache it and show it offline.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(NaturalizationGuideDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<NaturalizationGuideDto>> Get() =>
        Ok(await Mediator.Send(new GetGuideQuery()));
}
