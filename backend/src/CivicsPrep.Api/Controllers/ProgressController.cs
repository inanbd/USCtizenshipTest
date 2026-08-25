using CivicsPrep.Application.Features.Progress;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Progress;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>Per-user study progress: known marks, stars, and test history.</summary>
[Authorize]
public class ProgressController : ApiControllerBase
{
    /// <summary>Progress summary for a version, including the most recent test result.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(ProgressSummaryDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<ProgressSummaryDto>> Get([FromQuery] TestVersionDto? version) =>
        Ok(await Mediator.Send(new GetProgressSummaryQuery(version)));

    /// <summary>Marks a question known and/or starred.</summary>
    [HttpPut("questions/{number:int}")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<IActionResult> SetQuestionProgress(
        int number,
        SetQuestionProgressRequest request,
        [FromQuery] TestVersionDto? version)
    {
        await Mediator.Send(new SetQuestionProgressCommand(
            number, version, request.IsLearned, request.IsFavorite));
        return NoContent();
    }

    /// <summary>Clears the "known" marks for a version.</summary>
    [HttpPost("reset")]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Reset([FromQuery] TestVersionDto? version)
    {
        await Mediator.Send(new ResetProgressCommand(version));
        return NoContent();
    }

    /// <summary>Completed mock tests, newest first.</summary>
    [HttpGet("history")]
    [ProducesResponseType(typeof(IReadOnlyList<TestHistoryEntryDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<TestHistoryEntryDto>>> History(
        [FromQuery] TestVersionDto? version, [FromQuery] int limit = 50) =>
        Ok(await Mediator.Send(new GetTestHistoryQuery(version, limit)));
}
