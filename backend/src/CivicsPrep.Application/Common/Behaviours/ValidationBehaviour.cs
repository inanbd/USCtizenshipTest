using FluentValidation;
using MediatR;
using AppValidationException = CivicsPrep.Application.Common.Exceptions.ValidationException;

namespace CivicsPrep.Application.Common.Behaviours;

/// <summary>
/// Runs every FluentValidation validator registered for a request before its handler, so
/// handlers only ever see valid input.
/// </summary>
public class ValidationBehaviour<TRequest, TResponse>(IEnumerable<IValidator<TRequest>> validators)
    : IPipelineBehavior<TRequest, TResponse>
    where TRequest : notnull
{
    public async Task<TResponse> Handle(
        TRequest request,
        RequestHandlerDelegate<TResponse> next,
        CancellationToken cancellationToken)
    {
        var applicable = validators.ToList();
        if (applicable.Count == 0) return await next();

        var context = new ValidationContext<TRequest>(request);
        var results = await Task.WhenAll(
            applicable.Select(v => v.ValidateAsync(context, cancellationToken)));

        var failures = results
            .SelectMany(r => r.Errors)
            .Where(f => f is not null)
            .ToList();

        if (failures.Count != 0)
        {
            var errors = failures
                .GroupBy(f => f.PropertyName)
                .ToDictionary(g => g.Key, g => g.Select(f => f.ErrorMessage).Distinct().ToArray());
            throw new AppValidationException(errors);
        }

        return await next();
    }
}
