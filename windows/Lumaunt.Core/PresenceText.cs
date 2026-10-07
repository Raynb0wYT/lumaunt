using System.Globalization;
namespace Lumaunt.Core;
public static class PresenceText
{
    public static string TrimToLimit(string text, int limit)
    {
        ArgumentOutOfRangeException.ThrowIfNegative(limit);
        var boundaries=StringInfo.ParseCombiningCharacters(text);
        return boundaries.Length<=limit?text:text[..boundaries[limit]];
    }
}
