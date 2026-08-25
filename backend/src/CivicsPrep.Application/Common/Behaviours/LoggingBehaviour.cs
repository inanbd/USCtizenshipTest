using MediatR;
using Microsoft.Extensions.Logging;

namespace CivicsPrep.Application.Common.Behaviours;

/// <summary>Logs each request and how long its handler took.</summary>
public class LoggingBehaviour<TRequest, TResponse>(ILogger<LoggingBehaviour<TRequest, TResponse>> logger)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var name = typeof(TRequest).Name;
        var started = System.Diagnostics.Stopwatch.GetTimestamp();
        try
        {
            return await next();
        }
        finally
        {
            var elapsed = System.Diagnostics.Stopwatch.GetElapsedTime(started);
            logger.LogInformation("{RequestName} handled in {ElapsedMs}ms",
                name, elapsed.TotalMilliseconds);
        }
    }
}
