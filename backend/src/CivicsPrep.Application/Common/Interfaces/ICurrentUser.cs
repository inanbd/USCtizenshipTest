namespace CivicsPrep.Application.Common.Interfaces;

/// <summary>Who is making the current request.</summary>
public interface ICurrentUser
{
    /// <summary>The signed-in user's id, or null for anonymous callers.</summary>
    string? UserId { get; }

    bool IsAuthenticated => UserId is not null;

    /// <summary>The user id, or throws when the request requires authentication.</summary>
    string RequireUserId();
}
