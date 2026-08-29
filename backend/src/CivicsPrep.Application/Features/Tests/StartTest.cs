using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Features.Questions;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Contracts.Tests;
using CivicsPrep.Domain.Enums;
using CivicsPrep.Domain.Entities;
using CivicsPrep.Domain.Services;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Tests;

/// <summary>
/// Starts a mock test. The server picks the questions and stores what counts as correct, so
/// grading cannot be influenced by the client.
/// </summary>
public sealed record StartTestCommand(
    TestVersionDto? Version,
    TestSourceDto Source = TestSourceDto.All,
    int? QuestionCount = null) : IRequest<TestSessionDto>;

public class StartTestCommandValidator : AbstractValidator<StartTestCommand>
{
    public StartTestCommandValidator()
    {
        RuleFor(x => x.QuestionCount)
            .InclusiveBetween(1, 128)
            .When(x => x.QuestionCount is not null);
    }
}

public class StartTestCommandHandler(
    IApplicationDbContext db,
    ICurrentUser currentUser,
    UserContextLoader contextLoader,
    IQuestionShuffler shuffler,
    IClock clock) : IRequestHandler<StartTestCommand, TestSessionDto>
{
    public async Task<TestSessionDto> Handle(StartTestCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();
        var context = await contextLoader.LoadAsync(request.Version?.ToDomain(), ct);
        var version = request.Version?.ToDomain() ?? context.PreferredVersion;

        var all = await db.Questions
            .AsNoTracking()
            .Include(q => q.Answers)
            .Where(q => q.Version == version)
            .OrderBy(q => q.Number)
            .ToListAsync(ct);

        var source = request.Source.ToDomain();
        var pool = source switch
        {
            TestSource.Senior => all.Where(q => q.Senior).ToList(),
            TestSource.Starred => all.Where(q => context.Favorites.Contains(q.Number)).ToList(),
            _ => all,
        };

        if (pool.Count == 0)
        {
            throw new ConflictException(
                "There are no questions in that set to test. Star some questions first.");
        }

        var count = Math.Min(request.QuestionCount ?? version.AskedCount(), pool.Count);
        var selected = shuffler.Take(pool, count);

        var session = new TestSession
        {
            UserId = userId,
            Version = version,
            Source = source,
            StartedAt = clock.UtcNow,
        };

        for (var i = 0; i < selected.Count; i++)
        {
            var q = selected[i];
            var accepted = AnswerResolver.Resolve(
                q, context.Profile, context.State, context.Officials, context.SeededGovernor);

            session.Questions.Add(new TestSessionQuestion
            {
                Ordinal = i,
                QuestionNumber = q.Number,
                Prompt = q.Prompt,
                // Empty means the user must self-grade (state info not supplied yet).
                AcceptedAnswers = AcceptedAnswerCodec.Encode(accepted),
            });
        }

        db.TestSessions.Add(session);
        await db.SaveChangesAsync(ct);

        return TestSessionProjection.ToDto(session, all);
    }
}
