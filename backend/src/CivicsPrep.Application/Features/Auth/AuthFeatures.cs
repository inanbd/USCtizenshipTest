using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Auth;
using FluentValidation;
using MediatR;

namespace CivicsPrep.Application.Features.Auth;

public sealed record RegisterCommand(string Email, string Password, string? DisplayName)
    : IRequest<AuthResponse>;

public class RegisterCommandValidator : AbstractValidator<RegisterCommand>
{
    public RegisterCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress().MaximumLength(256);
        RuleFor(x => x.Password)
            .NotEmpty()
            .MinimumLength(8).WithMessage("Use at least 8 characters.")
            .MaximumLength(128)
            .Matches("[A-Za-z]").WithMessage("Include at least one letter.")
            .Matches("[0-9]").WithMessage("Include at least one digit.");
        RuleFor(x => x.DisplayName).MaximumLength(80);
    }
}

public class RegisterCommandHandler(IIdentityService identity)
    : IRequestHandler<RegisterCommand, AuthResponse>
{
    public Task<AuthResponse> Handle(RegisterCommand request, CancellationToken ct) =>
        identity.RegisterAsync(request.Email.Trim(), request.Password, request.DisplayName?.Trim(), ct);
}

public sealed record LoginCommand(string Email, string Password) : IRequest<AuthResponse>;

public class LoginCommandValidator : AbstractValidator<LoginCommand>
{
    public LoginCommandValidator()
    {
        RuleFor(x => x.Email).NotEmpty().EmailAddress();
        RuleFor(x => x.Password).NotEmpty();
    }
}

public class LoginCommandHandler(IIdentityService identity)
    : IRequestHandler<LoginCommand, AuthResponse>
{
    public Task<AuthResponse> Handle(LoginCommand request, CancellationToken ct) =>
        identity.LoginAsync(request.Email.Trim(), request.Password, ct);
}

public sealed record RefreshTokenCommand(string RefreshToken) : IRequest<AuthResponse>;

public class RefreshTokenCommandValidator : AbstractValidator<RefreshTokenCommand>
{
    public RefreshTokenCommandValidator() => RuleFor(x => x.RefreshToken).NotEmpty();
}

public class RefreshTokenCommandHandler(IIdentityService identity)
    : IRequestHandler<RefreshTokenCommand, AuthResponse>
{
    public Task<AuthResponse> Handle(RefreshTokenCommand request, CancellationToken ct) =>
        identity.RefreshAsync(request.RefreshToken, ct);
}

public sealed record LogoutCommand(string RefreshToken) : IRequest<Unit>;

public class LogoutCommandHandler(IIdentityService identity)
    : IRequestHandler<LogoutCommand, Unit>
{
    public async Task<Unit> Handle(LogoutCommand request, CancellationToken ct)
    {
        await identity.LogoutAsync(request.RefreshToken, ct);
        return Unit.Value;
    }
}

public sealed record GetCurrentUserQuery : IRequest<UserDto>;

public class GetCurrentUserQueryHandler(IIdentityService identity, ICurrentUser currentUser)
    : IRequestHandler<GetCurrentUserQuery, UserDto>
{
    public Task<UserDto> Handle(GetCurrentUserQuery request, CancellationToken ct) =>
        identity.GetCurrentUserAsync(currentUser.RequireUserId(), ct);
}
