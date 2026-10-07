namespace Lumaunt.Core;

public enum TimerMode { Elapsed, Countdown }
public sealed record PresenceButton(string Label, string Url);
public sealed record AppliedPresence(PresenceConfiguration Configuration, DateTimeOffset? Start, DateTimeOffset? End)
{
    public bool CanRestore(DateTimeOffset now) => !Configuration.DisableWhenTimerEnds || End is { } end && end>now;
    public bool ShouldDisable(DateTimeOffset now) => Configuration.DisableWhenTimerEnds && End is { } end && now >= end;
}
public sealed record PresenceConfiguration
{
    public string Details { get; init; } = "";
    public string State { get; init; } = "";
    public string LargeImage { get; init; } = "";
    public string LargeImageText { get; init; } = "";
    public string SmallImage { get; init; } = "";
    public string SmallImageText { get; init; } = "";
    public TimerMode TimerMode { get; init; }
    public DateTimeOffset? CustomStartTime { get; init; }
    public TimeSpan CountdownDuration { get; init; } = TimeSpan.FromHours(1);
    public bool DisableWhenTimerEnds { get; init; }
    public IReadOnlyList<PresenceButton> Buttons { get; init; } = Array.Empty<PresenceButton>();

    public AppliedPresence ApplyTimer(DateTimeOffset now, DateTimeOffset? restoredExpiration = null)
    {
        if (TimerMode == TimerMode.Elapsed)
        {
            if (CustomStartTime is { } start && (start < DateTimeOffset.UnixEpoch || start > now))
                throw new ArgumentOutOfRangeException(nameof(CustomStartTime), "Choose a start time between January 1, 1970 and now.");
            return new(this, CustomStartTime ?? now, null);
        }
        if (CountdownDuration <= TimeSpan.Zero) throw new ArgumentOutOfRangeException(nameof(CountdownDuration));
        return new(this, null, restoredExpiration ?? now.Add(CountdownDuration));
    }
}
