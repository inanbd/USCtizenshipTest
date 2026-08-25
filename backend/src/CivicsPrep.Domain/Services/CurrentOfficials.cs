namespace CivicsPrep.Domain.Services;

/// <summary>
/// The answers to the time-sensitive federal questions. Defaults are configured server-side and
/// a user may override any of them; USCIS directs applicants to verify the current answers at
/// uscis.gov/citizenship/testupdates.
/// </summary>
public sealed record CurrentOfficials(
    string President,
    string VicePresident,
    string Speaker,
    string ChiefJustice,
    string PresidentParty)
{
    public static CurrentOfficials Empty { get; } = new("", "", "", "", "");
}
