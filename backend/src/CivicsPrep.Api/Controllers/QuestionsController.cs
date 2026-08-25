using CivicsPrep.Application.Features.Questions;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Questions;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>
/// The official civics questions. Readable anonymously so the study content works before signing
/// in; per-user fields (learned, starred, resolved state answers) fill in once authenticated.
/// </summary>
[AllowAnonymous]
public class QuestionsController : ApiControllerBase
{
    /// <summary>Lists questions for a version, optionally filtered and searched.</summary>
    [HttpGet]
    [ProducesResponseType(typeof(QuestionListDto), StatusCodes.Status200OK)]
    public async Task<ActionResult<QuestionListDto>> List(
        [FromQuery] TestVersionDto? version,
        [FromQuery] QuestionFilter filter = QuestionFilter.All,
        [FromQuery] string? search = null) =>
        Ok(await Mediator.Send(new GetQuestionsQuery(version, filter, search)));

    /// <summary>Gets one question by its official number.</summary>
    [HttpGet("{number:int}")]
    [ProducesResponseType(typeof(QuestionDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status404NotFound)]
    public async Task<ActionResult<QuestionDto>> Get(
        int number, [FromQuery] TestVersionDto? version) =>
        Ok(await Mediator.Send(new GetQuestionQuery(number, version)));

    /// <summary>The USCIS sections for a version, in official order.</summary>
    [HttpGet("sections")]
    [ProducesResponseType(typeof(IReadOnlyList<SectionDto>), StatusCodes.Status200OK)]
    public async Task<ActionResult<IReadOnlyList<SectionDto>>> Sections(
        [FromQuery] TestVersionDto? version) =>
        Ok(await Mediator.Send(new GetSectionsQuery(version)));
}
