using CivicsPrep.Application.Features.Tests;
using CivicsPrep.Contracts.Tests;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>
/// Mock tests. The server picks the questions, stores what counts as correct, and grades every
/// answer, so a client cannot mark its own homework.
/// </summary>
[Authorize]
public class TestsController : ApiControllerBase
{
    /// <summary>Starts a mock test and returns its questions (without the answers).</summary>
    [HttpPost]
    [ProducesResponseType(typeof(TestSessionDto), StatusCodes.Status201Created)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<TestSessionDto>> Start(StartTestRequest request)
    {
        var session = await Mediator.Send(new StartTestCommand(
            request.Version, request.Source, request.QuestionCount));
        return CreatedAtAction(nameof(Get), new { id = session.Id }, session);
    }

    /// <summary>Re-reads an in-progress test, so a client can resume after a restart.</summary>
    [HttpGet("{id:guid}")]
    [ProducesResponseType(typeof(TestSessionDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TestSessionDto>> Get(Guid id) =>
        Ok(await Mediator.Send(new GetTestSessionQuery(id)));

    /// <summary>Submits one answer and returns whether it was correct.</summary>
    [HttpPost("{id:guid}/answers")]
    [ProducesResponseType(typeof(AnswerFeedbackDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AnswerFeedbackDto>> SubmitAnswer(
        Guid id, SubmitAnswerRequest request) =>
        Ok(await Mediator.Send(new SubmitAnswerCommand(id, request.Ordinal, request.Answer)));

    /// <summary>Overrides the automatic grade for one answer (self-graded questions).</summary>
    [HttpPost("{id:guid}/answers/override")]
    [ProducesResponseType(typeof(AnswerFeedbackDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<AnswerFeedbackDto>> OverrideAnswer(
        Guid id, OverrideAnswerRequest request) =>
        Ok(await Mediator.Send(new OverrideAnswerCommand(id, request.Ordinal, request.Correct)));

    /// <summary>Finishes the test and returns the result.</summary>
    [HttpPost("{id:guid}/complete")]
    [ProducesResponseType(typeof(TestResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TestResultDto>> Complete(Guid id) =>
        Ok(await Mediator.Send(new CompleteTestCommand(id)));

    /// <summary>The full result of a completed test, for review.</summary>
    [HttpGet("{id:guid}/result")]
    [ProducesResponseType(typeof(TestResultDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<TestResultDto>> Result(Guid id) =>
        Ok(await Mediator.Send(new GetTestResultQuery(id)));
}
