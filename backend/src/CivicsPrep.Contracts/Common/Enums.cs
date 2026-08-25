namespace CivicsPrep.Contracts.Common;

/// <summary>Wire representation of the test version. Mirrors the domain enum.</summary>
public enum TestVersionDto { V2008 = 1, V2020 = 2 }

public enum QuestionCategoryDto { AmericanGovernment = 1, AmericanHistory = 2, IntegratedCivics = 3 }

public enum AnswerKindDto
{
    Fixed = 0,
    President = 1, VicePresident = 2, Speaker = 3, ChiefJustice = 4, PresidentParty = 5,
    StateCapital = 10, Governor = 11, StateSenator = 12, StateRepresentative = 13,
}

public enum TestSourceDto { All = 0, Senior = 1, Starred = 2 }
