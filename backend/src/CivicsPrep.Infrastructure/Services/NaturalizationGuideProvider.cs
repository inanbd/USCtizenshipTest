using System.Reflection;
using System.Text.Json;
using CivicsPrep.Application.Common.Interfaces;
using CivicsPrep.Contracts.Guide;

namespace CivicsPrep.Infrastructure.Services;

/// <summary>
/// Reads the guide from the embedded <c>naturalization_guide.json</c>, which is the same file the
/// Flutter app bundles as an asset. One source of truth, so the app and the website cannot drift.
/// </summary>
public class NaturalizationGuideProvider : INaturalizationGuideProvider
{
    private const string ResourceName =
        "CivicsPrep.Infrastructure.SeedData.naturalization_guide.json";

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        PropertyNameCaseInsensitive = true,
    };

    private readonly Lazy<NaturalizationGuideDto> _guide = new(Load);

    public NaturalizationGuideDto Guide => _guide.Value;

    private static NaturalizationGuideDto Load()
    {
        var assembly = Assembly.GetExecutingAssembly();
        using var stream = assembly.GetManifestResourceStream(ResourceName)
            ?? throw new InvalidOperationException(
                $"Embedded resource '{ResourceName}' is missing. Run tools/export_seed_data.py.");

        return JsonSerializer.Deserialize<NaturalizationGuideDto>(stream, JsonOptions)
            ?? throw new InvalidOperationException("The naturalization guide failed to parse.");
    }
}
