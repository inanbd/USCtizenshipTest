using CivicsPrep.Application.Features.Auth;
using CivicsPrep.Contracts.Auth;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace CivicsPrep.Api.Controllers;

/// <summary>Registration and sign-in. Everything else in the API expects a bearer token.</summary>
public class AuthController : ApiControllerBase
{
    /// <summary>Creates an account and signs the new user in.</summary>
    [HttpPost("register")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status400BadRequest)]
    [ProducesResponseType(StatusCodes.Status409Conflict)]
    public async Task<ActionResult<AuthResponse>> Register(RegisterRequest request) =>
        Ok(await Mediator.Send(new RegisterCommand(
            request.Email, request.Password, request.DisplayName)));

    /// <summary>Signs in with email and password.</summary>
    [HttpPost("login")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponse>> Login(LoginRequest request) =>
        Ok(await Mediator.Send(new LoginCommand(request.Email, request.Password)));

    /// <summary>Exchanges a refresh token for a new access token. The old token is revoked.</summary>
    [HttpPost("refresh")]
    [AllowAnonymous]
    [ProducesResponseType(typeof(AuthResponse), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<AuthResponse>> Refresh(RefreshRequest request) =>
        Ok(await Mediator.Send(new RefreshTokenCommand(request.RefreshToken)));

    /// <summary>Revokes a refresh token.</summary>
    [HttpPost("logout")]
    [AllowAnonymous]
    [ProducesResponseType(StatusCodes.Status204NoContent)]
    public async Task<IActionResult> Logout(RefreshRequest request)
    {
        await Mediator.Send(new LogoutCommand(request.RefreshToken));
        return NoContent();
    }

    /// <summary>The signed-in user.</summary>
    [HttpGet("me")]
    [Authorize]
    [ProducesResponseType(typeof(UserDto), StatusCodes.Status200OK)]
    [ProducesResponseType(StatusCodes.Status401Unauthorized)]
    public async Task<ActionResult<UserDto>> Me() =>
        Ok(await Mediator.Send(new GetCurrentUserQuery()));
}
