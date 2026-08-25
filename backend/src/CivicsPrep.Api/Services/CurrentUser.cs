using System.Security.Claims;
using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Application.Common.Interfaces;

namespace CivicsPrep.Api.Services;

/// <summary>Reads the caller's identity from the validated JWT on the current request.</summary>
public class CurrentUser(IHttpContextAccessor accessor) : ICurrentUser
{
    public string? UserId =>
        accessor.HttpContext?.User.FindFirstValue(ClaimTypes.NameIdentifier)
        ?? accessor.HttpContext?.User.FindFirstValue("sub");

    public string RequireUserId() =>
        UserId ?? throw new UnauthorizedException("You must be signed in to do that.");
}
