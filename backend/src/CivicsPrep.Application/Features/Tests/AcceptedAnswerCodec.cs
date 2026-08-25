namespace CivicsPrep.Application.Features.Tests;

/// <summary>
/// Stores the accepted answers for a test question as a single column. A newline separator keeps
/// the snapshot readable in the database and round-trips exactly.
/// </summary>
public static class AcceptedAnswerCodec
{
    private const char Separator = '\n';

    public static string Encode(IEnumerable<string> answers) =>
        string.Join(Separator, answers.Where(a => !string.IsNullOrWhiteSpace(a)));

    public static IReadOnlyList<string> Decode(string? stored) =>
        string.IsNullOrEmpty(stored)
            ? []
            : stored.Split(Separator, StringSplitOptions.RemoveEmptyEntries);
}
