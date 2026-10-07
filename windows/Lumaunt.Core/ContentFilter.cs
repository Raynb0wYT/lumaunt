using System.Globalization;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
namespace Lumaunt.Core;
public sealed record ContentDecision(string? BlockedCategory, string? Reason, IReadOnlySet<string> ReviewCategories);
public static class ContentFilter
{
    private sealed record Rule(string Category, string Reason, string[][] Groups, string Matching, string Decision, string Relationship, int Distance);
    private static readonly Rule[] Rules = Load();
    private static Rule[] Load()
    {
        using var stream = typeof(ContentFilter).Assembly.GetManifestResourceStream("Lumaunt.Core.ModerationRules.json")!;
        return JsonSerializer.Deserialize<Rule[]>(stream)!;
    }
    private static string Unicode(string text) => string.Concat(text.Normalize(NormalizationForm.FormKD).EnumerateRunes()
        .Where(r => Rune.GetUnicodeCategory(r) is not UnicodeCategory.NonSpacingMark and not UnicodeCategory.SpacingCombiningMark and not UnicodeCategory.EnclosingMark)
        .Select(r => r.ToString())).ToLowerInvariant();
    private static string Words(string text) => Regex.Replace(Unicode(text).Replace('@','a').Replace('$','s'), @"[^\p{L}\p{N}]+", " ").Trim();
    private static string Obfuscated(string text) => string.Concat(Unicode(text).Select(c => c switch { '@' or '4' => 'a', '3' => 'e', '1' or '!' => 'i', '0' => 'o', '$' or '5' => 's', '7' => 't', _ => c }).Where(char.IsLetterOrDigit));
    private static bool Contains(string term, string text, string words, string matching)
    {
        var normalized = Words(term);
        if (normalized.Length == 0) return false;
        if (matching == "compactTerm") return words.Replace(" ", "").Contains(normalized.Replace(" ", ""));
        if (matching == "wholeTerm") return (" " + words + " ").Contains(" " + normalized + " ");
        var target = Obfuscated(term); var tokens = text.Split(' ', StringSplitOptions.RemoveEmptyEntries).Select(Obfuscated).ToArray();
        if (tokens.Contains(target)) return true;
        for (int i=0; target.Length >= 4 && i + target.Length <= tokens.Length; i++)
            if (tokens.Skip(i).Take(target.Length).All(t => t.Length == 1) && string.Concat(tokens.Skip(i).Take(target.Length)) == target) return true;
        return false;
    }
    private static List<(int Start,int End)> Matches(string[] terms, string[] tokens)
    {
        var result = new List<(int,int)>();
        foreach(var term in terms)
        {
            var t = Words(term).Split(' ', StringSplitOptions.RemoveEmptyEntries);
            for(int i=0; t.Length > 0 && i+t.Length <= tokens.Length; i++)
                if(tokens.Skip(i).Take(t.Length).SequenceEqual(t)) result.Add((i,i+t.Length-1));
        }
        return result;
    }
    private static bool Proximity(Rule rule, string words)
    {
        var tokens=words.Split(' ',StringSplitOptions.RemoveEmptyEntries);
        var groups=rule.Groups.Select(g=>Matches(g,tokens)).ToArray();
        if(groups.Any(g=>g.Count==0)) return false;
        bool Chain(int index,(int Start,int End) previous)
        {
            if(index==groups.Length) return true;
            foreach(var candidate in groups[index])
            {
                if(rule.Relationship=="orderedWithinTokens" && candidate.Start<=previous.End) continue;
                var gap=candidate.Start>previous.End ? candidate.Start-previous.End-1 : previous.Start>candidate.End ? previous.Start-candidate.End-1 : 0;
                if(gap<=rule.Distance && Chain(index+1,candidate)) return true;
            }
            return false;
        }
        return groups[0].Any(first=>Chain(1,first));
    }
    public static ContentDecision Evaluate(string text)
    {
        var words=Words(text); var review=new HashSet<string>();
        if(words.Length==0) return new(null,null,review);
        foreach(var rule in Rules)
        {
            var matches=rule.Relationship=="anywhere" ? rule.Groups.All(g=>g.Any(t=>Contains(t,text,words,rule.Matching))) : Proximity(rule,words);
            if(!matches) continue;
            if(rule.Decision=="block") return new(rule.Category,rule.Reason,review);
            review.Add(rule.Category);
        }
        return new(null,null,review);
    }
}
