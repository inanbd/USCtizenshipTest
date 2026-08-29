using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Questions;
using CivicsPrep.Domain.Enums;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Questions;

/// <summary>Which slice of the question set to return.</summary>
public enum QuestionFilter { All, Senior, Starred, NotLearned }

/// <summary>Lists the questions for a test version, filtered and searched.</summary>
public sealed record GetQuestionsQuery(
    TestVersionDto? Version = null,
    QuestionFilter Filter = QuestionFilter.All,
    string? Search = null) : IRequest<QuestionListDto>;

public class GetQuestionsQueryValidator : AbstractValidator<GetQuestionsQuery>
{
    public GetQuestionsQueryValidator()
    {
        RuleFor(x => x.Search).MaximumLength(200);
    }
}

public class GetQuestionsQueryHandler(IApplicationDbContext db, UserContextLoader contextLoader)
    : IRequestHandler<GetQuestionsQuery, QuestionListDto>
{
    public async Task<QuestionListDto> Handle(GetQuestionsQuery request, CancellationToken ct)
    {
        var context = await contextLoader.LoadAsync(request.Version?.ToDomain(), ct);
        var version = request.Version?.ToDomain() ?? context.PreferredVersion;

        var questions = await db.Questions
            .AsNoTracking()
            .Include(q => q.Answers)
            .Where(q => q.Version == version)
            .OrderBy(q => q.Number)
            .ToListAsync(ct);

        var dtos = questions
            .Select(q => QuestionProjection.ToDto(
                q, context.Profile, context.State, context.Officials,
                context.Learned, context.Favorites, context.SeededGovernor))
            .Where(dto => MatchesFilter(dto, request.Filter))
            .Where(dto => MatchesSearch(dto, request.Search))
            .ToList();

        return new QuestionListDto(
            version.ToDto(), dtos.Count, version.AskedCount(), version.PassCount(), dtos);
    }

    private static bool MatchesFilter(QuestionDto q, QuestionFilter filter) => filter switch
    {
        QuestionFilter.All => true,
        QuestionFilter.Senior => q.Senior,
        QuestionFilter.Starred => q.IsFavorite,
        QuestionFilter.NotLearned => !q.IsLearned,
        _ => true,
    };

    private static bool MatchesSearch(QuestionDto q, string? search)
    {
        if (string.IsNullOrWhiteSpace(search)) return true;
        var s = search.Trim();

        if (int.TryParse(s, out var number) && q.Number == number) return true;

        return q.Prompt.Contains(s, StringComparison.OrdinalIgnoreCase)
            || q.Answers.Any(a => a.Contains(s, StringComparison.OrdinalIgnoreCase))
            || q.Section.Contains(s, StringComparison.OrdinalIgnoreCase);
    }
}
