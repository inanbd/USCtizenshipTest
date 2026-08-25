using CivicsPrep.Contracts.Common;
using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Application.Mapping;

/// <summary>Translation between domain enums and their wire representations.</summary>
public static class DomainMapping
{
    public static TestVersionDto ToDto(this TestVersion v) => (TestVersionDto)(int)v;

    public static TestVersion ToDomain(this TestVersionDto v) => (TestVersion)(int)v;

    public static QuestionCategoryDto ToDto(this QuestionCategory c) => (QuestionCategoryDto)(int)c;

    public static AnswerKindDto ToDto(this AnswerKind k) => (AnswerKindDto)(int)k;

    public static Domain.Entities.TestSource ToDomain(this TestSourceDto s)
        => (Domain.Entities.TestSource)(int)s;

    public static TestSourceDto ToDto(this Domain.Entities.TestSource s) => (TestSourceDto)(int)s;

    public static string Label(this QuestionCategory c) => c switch
    {
        QuestionCategory.AmericanGovernment => "American Government",
        QuestionCategory.AmericanHistory => "American History",
        QuestionCategory.IntegratedCivics => "Integrated Civics",
        _ => c.ToString(),
    };
}
