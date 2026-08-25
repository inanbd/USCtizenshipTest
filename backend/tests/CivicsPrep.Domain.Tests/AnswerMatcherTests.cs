using CivicsPrep.Domain.Services;

namespace CivicsPrep.Domain.Tests;

/// <summary>
/// These mirror the Flutter client's matcher tests one-for-one. Grading must agree across the
/// app, the website and the API, so any divergence here is a real defect.
/// </summary>
public class AnswerMatcherTests
{
    [Theory]
    [InlineData("the constitution")]
    [InlineData("Constitution!")]
    [InlineData("  CONSTITUTION  ")]
    public void AcceptsExactAnswerRegardlessOfCaseAndPunctuation(string input)
        => Assert.True(AnswerMatcher.IsCorrect(input, ["the Constitution"]));

    [Theory]
    [InlineData("speech")]
    [InlineData("religion")]
    [InlineData("assembly")]
    public void AcceptsAnyOneOfSeveralAcceptedAnswers(string input)
        => Assert.True(AnswerMatcher.IsCorrect(input, ["speech", "religion", "assembly", "press"]));

    [Theory]
    [InlineData("the Declaration", "the Constitution")]
    [InlineData("Canada", "Mexico")]
    public void RejectsWrongAnswers(string input, string accepted)
        => Assert.False(AnswerMatcher.IsCorrect(input, [accepted]));

    [Theory]
    [InlineData("")]
    [InlineData("   ")]
    [InlineData("the of and")]
    public void RejectsEmptyOrContentFreeInput(string input)
        => Assert.False(AnswerMatcher.IsCorrect(input, ["the Constitution"]));

    [Fact]
    public void HandlesEmptyAcceptedAnswerList()
        => Assert.False(AnswerMatcher.IsCorrect("anything", []));

    [Theory]
    [InlineData("Madison", "(James) Madison")]
    [InlineData("James Madison", "(James) Madison")]
    [InlineData("27", "twenty-seven (27)")]
    [InlineData("twenty seven", "twenty-seven (27)")]
    public void MatchesWithOrWithoutParentheticalHints(string input, string accepted)
        => Assert.True(AnswerMatcher.IsCorrect(input, [accepted]));

    [Theory]
    [InlineData("it is the president", "the President")]
    [InlineData("the President of the United States", "the President")]
    [InlineData("I think it is Washington", "(George) Washington")]
    public void AcceptsLongerPhraseContainingTheAnswer(string input, string accepted)
        => Assert.True(AnswerMatcher.IsCorrect(input, [accepted]));

    [Theory]
    [InlineData("the Speaker", "the Speaker of the House")]
    [InlineData("18 and older", "Citizens eighteen (18) and older (can vote).")]
    public void AcceptsShorterPhraseDrawnFromTheAnswer(string input, string accepted)
        => Assert.True(AnswerMatcher.IsCorrect(input, [accepted]));

    [Theory]
    [InlineData("washinton", "(George) Washington")]
    [InlineData("constitucion", "the Constitution")]
    public void ToleratesTyposAndSpeechSlips(string input, string accepted)
        => Assert.True(AnswerMatcher.IsCorrect(input, [accepted]));

    [Theory]
    [InlineData("war", "bar")]
    [InlineData("Ohio", "Iowa")]
    public void DoesNotFuzzyMatchDifferentShortWords(string input, string accepted)
        => Assert.False(AnswerMatcher.IsCorrect(input, [accepted]));

    // --- the bugs the Flutter test suite caught; they must stay fixed here too ---

    [Fact]
    public void DoesNotAcceptVicePresidentForThePresident()
        => Assert.False(AnswerMatcher.IsCorrect("the Vice President", ["the President"]));

    [Fact]
    public void DoesNotAcceptThePresidentForTheVicePresident()
        => Assert.False(AnswerMatcher.IsCorrect("the President", ["the Vice President"]));

    [Fact]
    public void StillAcceptsTheCorrectOneOfThePair()
    {
        Assert.True(AnswerMatcher.IsCorrect("vice president", ["the Vice President"]));
        Assert.True(AnswerMatcher.IsCorrect("president", ["the President"]));
    }

    [Theory]
    [InlineData("not the Constitution", "the Constitution")]
    [InlineData("it is never the president", "the President")]
    public void RejectsNegatedAnswers(string input, string accepted)
        => Assert.False(AnswerMatcher.IsCorrect(input, [accepted]));

    [Fact]
    public void OneVagueWordCannotStandInForSeveralAnswers()
    {
        string[] freedoms =
        [
            "freedom of expression", "freedom of speech", "freedom of assembly",
            "freedom to petition the government", "freedom of religion",
            "the right to bear arms",
        ];
        var result = AnswerMatcher.Evaluate("freedom", freedoms, requiredCount: 2);
        Assert.Single(result.MatchedAnswers);
        Assert.False(result.Correct);
    }

    // --- multi-answer questions ---

    [Fact]
    public void RequiresTheFullNumberOfDistinctAnswers()
    {
        string[] parties = ["Democratic", "Republican"];
        Assert.False(AnswerMatcher.IsCorrect("Democratic", parties, 2));
        Assert.True(AnswerMatcher.IsCorrect("Democratic and Republican", parties, 2));
    }

    [Theory]
    [InlineData("republican, democratic")]
    [InlineData("republican/democratic")]
    public void AcceptsAnswersInAnyOrderAndSeparator(string input)
        => Assert.True(AnswerMatcher.IsCorrect(input, ["Democratic", "Republican"], 2));

    [Fact]
    public void TheSameAnswerIsNeverCreditedTwice()
    {
        var result = AnswerMatcher.Evaluate(
            "Democratic, Democratic", ["Democratic", "Republican"], 2);
        Assert.Equal(["Democratic"], result.MatchedAnswers);
        Assert.False(result.Correct);
    }

    [Fact]
    public void HandlesAThreeAnswerQuestion()
    {
        string[] states =
            ["New Hampshire", "Massachusetts", "Rhode Island", "Connecticut", "New York"];
        Assert.True(AnswerMatcher.IsCorrect("New York, Massachusetts, Connecticut", states, 3));
        Assert.False(AnswerMatcher.IsCorrect("New York, Massachusetts", states, 3));
    }

    [Fact]
    public void HandlesAFiveAnswerQuestion()
    {
        string[] states =
        [
            "New Hampshire", "Massachusetts", "Rhode Island", "Connecticut", "New York",
            "New Jersey", "Pennsylvania", "Delaware", "Georgia",
        ];
        Assert.True(AnswerMatcher.IsCorrect(
            "Georgia, Delaware, Pennsylvania, New Jersey, New York", states, 5));
    }

    [Fact]
    public void DistinguishesTheTwoHousesOfCongress()
    {
        string[] parts = ["the Senate", "the House of Representatives"];
        Assert.True(AnswerMatcher.IsCorrect("senate and house", parts, 2));
        Assert.False(AnswerMatcher.IsCorrect("senate", parts, 2));
    }

    [Fact]
    public void DistinguishesTwoCabinetPositions()
    {
        string[] cabinet = ["Secretary of State", "Secretary of Defense", "Secretary of Labor"];
        var result = AnswerMatcher.Evaluate(
            "Secretary of State and Secretary of Defense", cabinet, 2);
        Assert.True(result.Correct);
        Assert.Contains("Secretary of State", result.MatchedAnswers);
        Assert.Contains("Secretary of Defense", result.MatchedAnswers);
    }

    [Fact]
    public void ReportsWhichAnswersTheUserCovered()
    {
        var result = AnswerMatcher.Evaluate(
            "life and liberty", ["life", "liberty", "pursuit of happiness"], 2);
        Assert.True(result.Correct);
        Assert.Equal(["life", "liberty"], result.MatchedAnswers);
    }

    [Fact]
    public void ReturnsNoMatchesForAWrongAnswer()
    {
        var result = AnswerMatcher.Evaluate("bananas", ["life", "liberty"]);
        Assert.False(result.Correct);
        Assert.Empty(result.MatchedAnswers);
    }
}
