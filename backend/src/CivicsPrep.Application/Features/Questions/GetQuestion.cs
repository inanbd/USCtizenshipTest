using CivicsPrep.Domain.Enums;
using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Questions;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Questions;

/// <summary>Fetches one question by its official number.</summary>
public sealed record GetQuestionQuery(int Number, TestVersionDto? Version = null)
    : IRequest<QuestionDto>;

public class GetQuestionQueryHandler(IApplicationDbContext db, UserContextLoader contextLoader)
    : IRequestHandler<GetQuestionQuery, QuestionDto>
{
    public async Task<QuestionDto> Handle(GetQuestionQuery request, CancellationToken ct)
    {
        var context = await contextLoader.LoadAsync(request.Version?.ToDomain(), ct);
        var version = request.Version?.ToDomain() ?? context.PreferredVersion;

        var question = await db.Questions
            .AsNoTracking()
            .Include(q => q.Answers)
            .FirstOrDefaultAsync(q => q.Version == version && q.Number == request.Number, ct)
            ?? throw new NotFoundException(
                $"Question {request.Number} was not found in the {version.ShortLabel()} set.");

        return QuestionProjection.ToDto(
            question, context.Profile, context.State, context.Officials,
            context.Learned, context.Favorites);
    }
}
