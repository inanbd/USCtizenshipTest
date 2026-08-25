using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Infrastructure.Persistence;
using CivicsPrep.Infrastructure.Persistence.Seeding;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;

namespace CivicsPrep.Api.Tests;

/// <summary>
/// Boots the real API - real controllers, real CQRS pipeline, real seed data - against an
/// in-memory SQLite database, so the tests exercise the same code paths production does.
/// </summary>
public class CivicsPrepApiFactory : WebApplicationFactory<Program>, IAsyncLifetime
{
    private SqliteConnection _connection = null!;

    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");

        // UseSetting feeds configuration before the WebApplicationBuilder reads it, which
        // ConfigureAppConfiguration does not do under minimal hosting.
        var settings = new Dictionary<string, string?>
        {
            // The API migrates SQL Server on boot; the tests create the SQLite schema instead.
            ["Database:AutoMigrate"] = "false",
            ["Jwt:SigningKey"] = "integration-test-signing-key-at-least-32-bytes-long",
            ["Jwt:Issuer"] = "CivicsPrepTests",
            ["Jwt:Audience"] = "CivicsPrepTests",
            ["Officials:President"] = "Test President",
            ["Officials:VicePresident"] = "Test Vice President",
            ["Officials:Speaker"] = "Test Speaker",
            ["Officials:ChiefJustice"] = "Test Chief Justice",
            ["Officials:PresidentParty"] = "Test Party",
            ["Congress:ApiKey"] = "",
        };
        foreach (var (key, value) in settings) builder.UseSetting(key, value);

        builder.ConfigureServices(services =>
        {
            // Swap SQL Server for the shared in-memory SQLite connection.
            // EF Core registers its provider through several options-related services. Removing
            // them by name keeps this working across EF versions; leaving any behind makes EF
            // complain that two providers are registered.
            foreach (var descriptor in services
                .Where(d => d.ServiceType.FullName?.Contains("DbContextOptions") == true)
                .ToList())
            {
                services.Remove(descriptor);
            }
            services.RemoveAll<ApplicationDbContext>();

            services.AddDbContext<ApplicationDbContext>(options =>
                options.UseSqlite(_connection));

            // Deterministic question selection so test assertions are stable.
            services.RemoveAll<IQuestionShuffler>();
            services.AddSingleton<IQuestionShuffler, InOrderQuestionShuffler>();
        });
    }

    public async Task InitializeAsync()
    {
        // A single open connection keeps the in-memory database alive for the whole fixture.
        _connection = new SqliteConnection("DataSource=:memory:");
        await _connection.OpenAsync();

        using var scope = Services.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<ApplicationDbContext>();
        await db.Database.EnsureCreatedAsync();

        var seeder = scope.ServiceProvider.GetRequiredService<DatabaseSeeder>();
        await seeder.SeedAsync();
    }

    // Explicit, because the base class already exposes a ValueTask-returning DisposeAsync.
    async Task IAsyncLifetime.DisposeAsync()
    {
        if (_connection is not null) await _connection.DisposeAsync();
        await base.DisposeAsync();
    }
}

/// <summary>Takes questions in order, so a test knows exactly which ones it will be asked.</summary>
public class InOrderQuestionShuffler : IQuestionShuffler
{
    public IReadOnlyList<T> Take<T>(IReadOnlyList<T> source, int count) =>
        [.. source.Take(Math.Min(count, source.Count))];
}
