using System.Reflection;
using CivicsPrep.Application.Common.Behaviours;
using FluentValidation;
using Microsoft.Extensions.DependencyInjection;

namespace CivicsPrep.Application;

public static class DependencyInjection
{
    /// <summary>Registers the CQRS pipeline, its behaviours, and every validator in this assembly.</summary>
    public static IServiceCollection AddApplication(this IServiceCollection services)
    {
        var assembly = Assembly.GetExecutingAssembly();

        services.AddMediatR(cfg =>
        {
            cfg.RegisterServicesFromAssembly(assembly);
            cfg.AddOpenBehavior(typeof(LoggingBehaviour<,>));
            cfg.AddOpenBehavior(typeof(ValidationBehaviour<,>));
        });

        services.AddValidatorsFromAssembly(assembly, includeInternalTypes: true);

        services.AddScoped<Features.Questions.UserContextLoader>();

        return services;
    }
}
