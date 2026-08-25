using CivicsPrep.Domain.Enums;

namespace CivicsPrep.Domain.Entities;

/// <summary>A single civics question from an official USCIS test.</summary>
public class Question
{
    public int Id { get; set; }

    /// <summary>Official question number within its test version (1-based).</summary>
    public int Number { get; set; }

    public TestVersion Version { get; set; }
    public QuestionCategory Category { get; set; }

    /// <summary>USCIS subsection, e.g. "Principles of American Democracy".</summary>
    public string Section { get; set; } = string.Empty;

    public string Prompt { get; set; } = string.Empty;

    public AnswerKind Kind { get; set; }

    /// <summary>True if marked with an asterisk for the 65/20 exemption.</summary>
    public bool Senior { get; set; }

    /// <summary>How many distinct answers the applicant must give ("Name two..." -&gt; 2).</summary>
    public int RequiredCount { get; set; } = 1;

    /// <summary>Extra guidance shown to the user (official notes, verify reminders).</summary>
    public string? Note { get; set; }

    /// <summary>
    /// The statically-listed accepted answers. For dynamic kinds these hold the official
    /// placeholder text and the real answers are resolved per user at request time.
    /// </summary>
    public List<QuestionAnswer> Answers { get; set; } = [];

    public bool IsDynamic => Kind.IsDynamic();
    public bool IsStateDependent => Kind.IsStateDependent();
    public bool IsTimeSensitive => Kind.IsTimeSensitive();
}

/// <summary>One accepted answer for a <see cref="Question"/>.</summary>
public class QuestionAnswer
{
    public int Id { get; set; }
    public int QuestionId { get; set; }
    public Question? Question { get; set; }

    public string Text { get; set; } = string.Empty;

    /// <summary>Preserves the order USCIS lists the answers in.</summary>
    public int Ordinal { get; set; }
}
