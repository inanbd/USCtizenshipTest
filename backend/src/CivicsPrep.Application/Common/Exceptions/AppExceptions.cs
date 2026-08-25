namespace CivicsPrep.Application.Common.Exceptions;

/// <summary>Input failed validation. Surfaces as HTTP 400 with per-field errors.</summary>
public class ValidationException(IReadOnlyDictionary<string, string[]> errors)
    : Exception("One or more validation errors occurred.")
{
    public IReadOnlyDictionary<string, string[]> Errors { get; } = errors;
}

/// <summary>The requested resource does not exist (or is not visible to this user). HTTP 404.</summary>
public class NotFoundException(string message) : Exception(message);

/// <summary>The request is understood but not allowed in the current state. HTTP 409.</summary>
public class ConflictException(string message) : Exception(message);

/// <summary>Authentication failed or the caller is not permitted. HTTP 401.</summary>
public class UnauthorizedException(string message) : Exception(message);

/// <summary>A dependency the feature needs is unavailable or misconfigured. HTTP 502/400.</summary>
public class ExternalServiceException(string message) : Exception(message);
