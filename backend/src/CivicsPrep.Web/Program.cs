using CivicsPrep.Web;
using CivicsPrep.Web.Services;
using Microsoft.AspNetCore.Components.Authorization;
using Microsoft.AspNetCore.Components.Web;
using Microsoft.AspNetCore.Components.WebAssembly.Hosting;
using Microsoft.Extensions.DependencyInjection;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

// Where the API lives. Override in wwwroot/appsettings.json per environment.
var apiBaseUrl = builder.Configuration["ApiBaseUrl"] ?? "https://localhost:7100/";

builder.Services.AddScoped<IBrowserStorage, BrowserStorage>();

builder.Services.AddScoped<ApiAuthenticationStateProvider>();
builder.Services.AddScoped<AuthenticationStateProvider>(sp =>
    sp.GetRequiredService<ApiAuthenticationStateProvider>());
builder.Services.AddAuthorizationCore();

builder.Services.AddScoped<AuthorizedHandler>();

// Bare client used only by the token refresh, so refreshing cannot recurse.
builder.Services.AddHttpClient("CivicsPrepApi.Bare",
    client => client.BaseAddress = new Uri(apiBaseUrl));

builder.Services.AddHttpClient<CivicsApiClient>(
        client => client.BaseAddress = new Uri(apiBaseUrl))
    .AddHttpMessageHandler<AuthorizedHandler>();

await builder.Build().RunAsync();
