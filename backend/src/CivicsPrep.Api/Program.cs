using System.Text.Json.Serialization;
using CivicsPrep.Api.Middleware;
using CivicsPrep.Api.Services;
using CivicsPrep.Application;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Infrastructure;
using CivicsPrep.Infrastructure.Persistence;
using CivicsPrep.Infrastructure.Persistence.Seeding;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.OpenApi;

var builder = WebApplication.CreateBuilder(args);

builder.Services
    .AddControllers()
    .AddJsonOptions(options =>
    {
        // Enums travel as their names, which keeps the API readable and stable.
        options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    });

// Validation is handled by the CQRS pipeline, so the framework's automatic 400 is turned off
// to keep one consistent error shape.
builder.Services.Configure<ApiBehaviorOptions>(o => o.SuppressModelStateInvalidFilter = true);

builder.Services.AddHttpContextAccessor();
builder.Services.AddScoped<ICurrentUser, CurrentUser>();

builder.Services.AddApplication();
builder.Services.AddInfrastructure(builder.Configuration);
builder.Services.AddJwtAuthentication(builder.Configuration);

builder.Services.AddHealthChecks().AddDbContextCheck<ApplicationDbContext>();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen(options =>
{
    options.SwaggerDoc("v1", new OpenApiInfo
    {
        Title = "Civics Prep API",
        Version = "v1",
        Description =
            "Backend for the U.S. citizenship civics test study app. Serves both official "
            + "question sets, grades mock tests, and tracks per-user progress.",
    });

    options.AddSecurityDefinition("Bearer", new OpenApiSecurityScheme
    {
        Name = "Authorization",
        Type = SecuritySchemeType.Http,
        Scheme = "bearer",
        BearerFormat = "JWT",
        In = ParameterLocation.Header,
        Description = "Paste the access token returned by /api/auth/login.",
    });

    options.AddSecurityRequirement(_ => new OpenApiSecurityRequirement
    {
        [new OpenApiSecuritySchemeReference("Bearer")] = [],
    });
});

// The Blazor client is served from a different origin in development.
const string WebClientCors = "WebClient";
builder.Services.AddCors(options => options.AddPolicy(WebClientCors, policy =>
{
    var origins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()
        ?? ["https://localhost:7150", "http://localhost:5150"];
    policy.WithOrigins(origins).AllowAnyHeader().AllowAnyMethod();
}));

var app = builder.Build();

app.UseMiddleware<ExceptionHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI(o => o.SwaggerEndpoint("/swagger/v1/swagger.json", "Civics Prep API v1"));
}

app.UseCors(WebClientCors);
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();
app.MapHealthChecks("/health");

await MigrateAndSeedAsync(app);

await app.RunAsync();

/// <summary>
/// Applies migrations and loads the official question set on startup, so a fresh database (or a
/// fresh container) comes up ready to use.
/// </summary>
static async Task MigrateAndSeedAsync(WebApplication app)
{
    if (app.Configuration.GetValue("Database:AutoMigrate", true) is false) return;

    using var scope = app.Services.CreateScope();
    var logger = scope.ServiceProvider.GetRequiredService<ILogger<Program>>();

    try
    {
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();

        // The migrations are SQL Server's; SQLite (local dev) builds the schema from the model.
        if (db.Database.IsSqlite())
        {
            await db.Database.EnsureCreatedAsync();
        }
        else
        {
            await db.Database.MigrateAsync();
        }

        var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
        await seeder.SeedAsync();
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "Database migration or seeding failed.");
        throw;
    }
}

/// <summary>Exposed so the integration tests can spin the API up with WebApplicationFactory.</summary>
public partial class Program;
