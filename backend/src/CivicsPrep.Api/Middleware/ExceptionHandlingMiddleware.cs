using System.Text.Json;
using CivicsPrep.Application.Common.Exceptions;
using CivicsPrep.Contracts.Common;
using AppValidationException = CivicsPrep.Application.Common.Exceptions.ValidationException;

namespace CivicsPrep.Api.Middleware;

/// <summary>
/// Turns application exceptions into consistent problem responses, so clients get a predictable
/// error shape and internal details never leak.
/// </summary>
public class ExceptionHandlingMiddleware(
    RequestDelegate next,
    ILogger<ExceptionHandlingMiddleware> logger,
    IHostEnvironment environment)
{
    private static readonly JsonSerializerOptions JsonOptions =
        new(JsonSerializerDefaults.Web);

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (Exception ex)
        {
            await WriteAsync(context, ex);
        }
    }

    private async Task WriteAsync(HttpContext context, Exception ex)
    {
        var (status, title, detail, errors) = Translate(ex);

        if (status >= StatusCodes.Status500InternalServerError)
        {
            logger.LogError(ex, "Unhandled exception on {Method} {Path}",
                context.Request.Method, context.Request.Path);
        }
        else
        {
            logger.LogInformation("{Status} on {Method} {Path}: {Title}",
                status, context.Request.Method, context.Request.Path, title);
        }

        if (context.Response.HasStarted) return;

        context.Response.Clear();
        context.Response.StatusCode = status;
        context.Response.ContentType = "application/problem+json";

        var body = new ApiProblemDto(title, status, detail, errors);
        await context.Response.WriteAsync(JsonSerializer.Serialize(body, JsonOptions));
    }

    private (int Status, string Title, string? Detail, IReadOnlyDictionary<string, string[]>? Errors)
        Translate(Exception ex) => ex switch
    {
        AppValidationException v =>
            (StatusCodes.Status400BadRequest, "One or more validation errors occurred.", null, v.Errors),

        UnauthorizedException u =>
            (StatusCodes.Status401Unauthorized, "Not signed in.", u.Message, null),

        NotFoundException n =>
            (StatusCodes.Status404NotFound, "Not found.", n.Message, null),

        ConflictException c =>
            (StatusCodes.Status409Conflict, "Conflict.", c.Message, null),

        ExternalServiceException e =>
            (StatusCodes.Status502BadGateway, "Upstream service unavailable.", e.Message, null),

        _ => (
            StatusCodes.Status500InternalServerError,
            "An unexpected error occurred.",
            // Only surface exception text outside production.
            environment.IsDevelopment() ? ex.ToString() : null,
            null),
    };
}
