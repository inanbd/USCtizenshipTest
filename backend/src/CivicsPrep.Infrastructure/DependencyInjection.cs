using System.Text;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Infrastructure.Identity;
using CivicsPrep.Infrastructure.Persistence;
using CivicsPrep.Infrastructure.Persistence.Seeding;
using CivicsPrep.Infrastructure.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.IdentityModel.Tokens;

namespace CivicsPrep.Infrastructure;

/// <summary>Supported values for the "Database:Provider" setting.</summary>
public static class DatabaseProviders
{
    public const string SqlServer = "SqlServer";
    public const string Sqlite = "Sqlite";
}

public static class DependencyInjection
{
    /// <summary>
    /// Registers persistence, identity and the outbound integrations. The API only knows about
    /// this one entry point, which keeps SQL Server and Identity out of the other layers.
    /// </summary>
    public static IServiceCollection AddInfrastructure(
        this IServiceCollection services, IConfiguration configuration)
    {
        var connectionString = configuration.GetConnectionString("DefaultConnection");
        var provider = configuration["Database:Provider"] ?? DatabaseProviders.SqlServer;

        services.AddDbContext<ApplicationDbContext>(options =>
        {
            // SQL Server is the deployment target; SQLite keeps local development and the
            // integration tests free of a database server.
            if (provider.Equals(DatabaseProviders.Sqlite, StringComparison.OrdinalIgnoreCase))
            {
                options.UseSqlite(connectionString);
            }
            else
            {
                options.UseSqlServer(connectionString, sql => sql.EnableRetryOnFailure());
            }
        });

        services.AddScoped<IApplicationDbContext>(sp =>
            sp.GetRequiredService<ApplicationDbContext>());

        services.AddIdentityCore<ApplicationUser>(options =>
            {
                options.User.RequireUniqueEmail = true;
                options.Password.RequiredLength = 8;
                options.Password.RequireNonAlphanumeric = false;
                options.Password.RequireUppercase = false;
            })
            .AddEntityFrameworkStores<ApplicationDbContext>()
            .AddDefaultTokenProviders();

        services.Configure<JwtOptions>(configuration.GetSection(JwtOptions.SectionName));
        services.Configure<OfficialsOptions>(configuration.GetSection(OfficialsOptions.SectionName));
        services.Configure<CongressOptions>(configuration.GetSection(CongressOptions.SectionName));

        services.AddScoped<IIdentityService, IdentityService>();
        services.AddScoped<DatabaseSeeder>();

        services.AddSingleton<IClock, SystemClock>();
        services.AddSingleton<IOfficialsProvider, OfficialsProvider>();
        services.AddSingleton<IQuestionShuffler, RandomQuestionShuffler>();

        services.AddMemoryCache();
        services.AddHttpClient<ICongressDirectory, CongressDirectory>(client =>
        {
            client.Timeout = TimeSpan.FromSeconds(15);
            client.DefaultRequestHeaders.Add("Accept", "application/json");
        });

        return services;
    }

    /// <summary>Configures JWT bearer authentication using the same options the issuer uses.</summary>
    public static IServiceCollection AddJwtAuthentication(
        this IServiceCollection services, IConfiguration configuration)
    {
        var jwt = configuration.GetSection(JwtOptions.SectionName).Get<JwtOptions>() ?? new JwtOptions();

        if (string.IsNullOrWhiteSpace(jwt.SigningKey))
        {
            throw new InvalidOperationException(
                "Jwt:SigningKey is not configured. Set it via configuration, an environment "
                + "variable, or user-secrets before starting the API.");
        }

        services.AddAuthentication(options =>
            {
                options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
                options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
            })
            .AddJwtBearer(options =>
            {
                options.TokenValidationParameters = new TokenValidationParameters
                {
                    ValidateIssuer = true,
                    ValidateAudience = true,
                    ValidateLifetime = true,
                    ValidateIssuerSigningKey = true,
                    ValidIssuer = jwt.Issuer,
                    ValidAudience = jwt.Audience,
                    IssuerSigningKey = new SymmetricSecurityKey(
                        Encoding.UTF8.GetBytes(jwt.SigningKey)),
                    ClockSkew = TimeSpan.FromSeconds(30),
                };
            });

        services.AddAuthorization();
        return services;
    }
}
