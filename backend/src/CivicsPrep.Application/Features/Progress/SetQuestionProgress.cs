using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Application.Mapping;
using CivicsPrep.Contracts.Common;
using CivicsPrep.Domain.Enums;
using CivicsPrep.Domain.Entities;
using FluentValidation;
using MediatR;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Progress;

/// <summary>Marks a question known and/or starred for the signed-in user.</summary>
public sealed record SetQuestionProgressCommand(
    int Number,
    TestVersionDto? Version,
    bool? IsLearned,
    bool? IsFavorite) : IRequest<Unit>;

public class SetQuestionProgressCommandValidator : AbstractValidator<SetQuestionProgressCommand>
{
    public SetQuestionProgressCommandValidator()
    {
        RuleFor(x => x.Number).GreaterThan(0);
        RuleFor(x => x)
            .Must(x => x.IsLearned is not null || x.IsFavorite is not null)
            .WithName("body")
            .WithMessage("Provide isLearned, isFavorite, or both.");
    }
}

public class SetQuestionProgressCommandHandler(
    IApplicationDbContext db, ICurrentUser currentUser, IClock clock)
    : IRequestHandler<SetQuestionProgressCommand, Unit>
{
    public async Task<Unit> Handle(SetQuestionProgressCommand request, CancellationToken ct)
    {
        var userId = currentUser.RequireUserId();

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);
        var version = request.Version?.ToDomain() ?? profile?.TestVersion
            ?? Domain.Enums.TestVersion.V2008;

        var exists = await db.Questions
            .AnyAsync(q => q.Version == version && q.Number == request.Number, ct);
        if (!exists)
        {
            throw new NotFoundException(
                $"Question {request.Number} was not found in the {version.ShortLabel()} set.");
        }

        var row = await db.UserQuestionProgress.FirstOrDefaultAsync(
            p => p.UserId == userId && p.Version == version && p.QuestionNumber == request.Number,
            ct);

        if (row is null)
        {
            row = new UserQuestionProgress
            {
                UserId = userId,
                Version = version,
                QuestionNumber = request.Number,
            };
            db.UserQuestionProgress.Add(row);
        }

        if (request.IsLearned is not null) row.IsLearned = request.IsLearned.Value;
        if (request.IsFavorite is not null) row.IsFavorite = request.IsFavorite.Value;
        row.UpdatedAt = clock.UtcNow;

        await db.SaveChangesAsync(ct);
        return Unit.Value;
    }
}
