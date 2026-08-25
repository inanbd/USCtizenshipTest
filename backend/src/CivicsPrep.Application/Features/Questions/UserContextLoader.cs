using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Domain.Entities;
using CivicsPrep.Domain.Enums;
using CivicsPrep.Domain.Services;
using Microsoft.EntityFrameworkCore;

namespace CivicsPrep.Application.Features.Questions;

/// <summary>
/// Everything a handler needs to answer "what is correct for this user": their profile, their
/// state, the effective officials, and their per-question progress.
/// </summary>
public sealed record UserContext(
    UserProfile? Profile,
    UsState? State,
    CurrentOfficials Officials,
    IReadOnlySet<int> Learned,
    IReadOnlySet<int> Favorites)
{
    public TestVersion PreferredVersion => Profile?.TestVersion ?? TestVersion.V2008;
}

/// <summary>Loads <see cref="UserContext"/> for the signed-in user (or an anonymous default).</summary>
public class UserContextLoader(
    IApplicationDbContext db,
    ICurrentUser currentUser,
    IOfficialsProvider officialsProvider)
{
    public async Task<UserContext> LoadAsync(
        TestVersion? version = null, CancellationToken ct = default)
    {
        var userId = currentUser.UserId;
        if (userId is null)
        {
            return new UserContext(null, null, officialsProvider.Defaults,
                new HashSet<int>(), new HashSet<int>());
        }

        var profile = await db.UserProfiles.FirstOrDefaultAsync(p => p.UserId == userId, ct);

        UsState? state = null;
        if (!string.IsNullOrWhiteSpace(profile?.StateCode))
        {
            state = await db.States.FirstOrDefaultAsync(s => s.Code == profile!.StateCode, ct);
        }

        var effectiveVersion = version ?? profile?.TestVersion ?? TestVersion.V2008;

        var progress = await db.UserQuestionProgress
            .Where(p => p.UserId == userId && p.Version == effectiveVersion)
            .ToListAsync(ct);

        var learned = progress.Where(p => p.IsLearned).Select(p => p.QuestionNumber).ToHashSet();
        var favorites = progress.Where(p => p.IsFavorite).Select(p => p.QuestionNumber).ToHashSet();

        return new UserContext(
            profile, state, ResolveOfficials(profile), learned, favorites);
    }

    private CurrentOfficials ResolveOfficials(UserProfile? profile)
    {
        var d = officialsProvider.Defaults;
        if (profile is null) return d;

        return new CurrentOfficials(
            Or(profile.President, d.President),
            Or(profile.VicePresident, d.VicePresident),
            Or(profile.Speaker, d.Speaker),
            Or(profile.ChiefJustice, d.ChiefJustice),
            Or(profile.PresidentParty, d.PresidentParty));

        static string Or(string? a, string b) => string.IsNullOrWhiteSpace(a) ? b : a;
    }
}
