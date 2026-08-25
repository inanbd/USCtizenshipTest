using CivicsPrep.Application.Features.StudyPlans;
using CivicsPrep.Contracts.StudyPlans;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>The user's day-by-day study plan, generated from their interview date.</summary>
[Authorize]
[Route("api/study-plan")]
public class StudyPlansController : ApiControllerBase
{
    /// <summary>The current plan, or 204 when the user has not made one.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(StudyPlanDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<ActionResult<StudyPlanDto>> Get()
    {
        var plan = await Mediator.Send(new GetStudyPlanQuery());
        return plan is null ? NoContent() : Ok(plan);
    }

    /// <summary>Creates a plan, replacing any existing one.</summary>
    [HttpPost]
    [ProducesResponseType(typeof(StudyPlanDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    public async Task<ActionResult<StudyPlanDto>> Create(CreateStudyPlanRequest request) =>
        Ok(await Mediator.Send(new CreateStudyPlanCommand(
            request.TestDate, request.Version, request.SeniorOnly)));

    /// <summary>Ticks a day off (or un-ticks it).</summary>
    [HttpPut("days/{dayNumber:int}")]
    [ProducesResponseType(typeof(StudyPlanDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<StudyPlanDto>> SetDayComplete(
        int dayNumber, SetDayCompleteRequest request) =>
        Ok(await Mediator.Send(new SetStudyDayCompleteCommand(dayNumber, request.IsComplete)));

    /// <summary>Clears the plan.</summary>
    [HttpDelete]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Delete()
    {
        await Mediator.Send(new DeleteStudyPlanCommand());
        return NoContent();
    }
}
