using System.Text.Json.Serialization;

namespace CivicsPrep.Infrastructure.Persistence.Seeding;

/// <summary>Shape of the generated questions.json (see backend/tools/export_seed_data.py).</summary>
public sealed class SeedQuestion
{
    [JsonPropertyName("id")] public int Number { get; set; }
    [JsonPropertyName("version")] public string Version { get; set; } = "";
    [JsonPropertyName("category")] public string Category { get; set; } = "";
    [JsonPropertyName("section")] public string Section { get; set; } = "";
    [JsonPropertyName("prompt")] public string Prompt { get; set; } = "";
    [JsonPropertyName("answers")] public List<string> Answers { get; set; } = [];
    [JsonPropertyName("kind")] public string Kind { get; set; } = "fixed";
    [JsonPropertyName("senior")] public bool Senior { get; set; }
    [JsonPropertyName("requiredCount")] public int RequiredCount { get; set; } = 1;
    [JsonPropertyName("note")] public string? Note { get; set; }
}

public sealed class SeedState
{
    [JsonPropertyName("code")] public string Code { get; set; } = "";
    [JsonPropertyName("name")] public string Name { get; set; } = "";
    [JsonPropertyName("capital")] public string Capital { get; set; } = "";
}

/// <summary>Shape of the generated governors.json.</summary>
public sealed class SeedGovernorFile
{
    [JsonPropertyName("asOf")] public string AsOf { get; set; } = "";
    [JsonPropertyName("source")] public string? Source { get; set; }
    [JsonPropertyName("governors")] public List<SeedGovernor> Governors { get; set; } = [];
}

public sealed class SeedGovernor
{
    [JsonPropertyName("stateCode")] public string StateCode { get; set; } = "";
    [JsonPropertyName("name")] public string Name { get; set; } = "";
    [JsonPropertyName("since")] public string? Since { get; set; }
}
