using System.Globalization;
namespace Lumaunt.Core;
public static class PresenceValidation
{
    public static void Validate(PresenceConfiguration p, DateTimeOffset now)
    {
        if(!Enum.IsDefined(p.TimerMode)) throw new ArgumentException("Invalid timer mode.");
        if(p.Buttons==null || p.Buttons.Any(b=>b==null || b.Label==null || b.Url==null) || p.Details==null || p.State==null || p.LargeImage==null || p.SmallImage==null || p.LargeImageText==null || p.SmallImageText==null) throw new ArgumentException("Invalid presence configuration.");
        foreach(var (name,text) in Fields(p)) if(new StringInfo(text).LengthInTextElements> (name.StartsWith("Button") ? 32 : 128)) throw new ArgumentException($"{name} is too long.");
        if(p.Buttons.Count>2) throw new ArgumentException("Discord supports at most two buttons.");
        foreach(var button in p.Buttons)
            if(string.IsNullOrWhiteSpace(button.Label) || !IsWebUrl(button.Url)) throw new ArgumentException("Each button needs a label and a valid HTTP or HTTPS URL.");
        if(p.TimerMode==TimerMode.Countdown && (p.CountdownDuration<TimeSpan.FromMinutes(1) || p.CountdownDuration>TimeSpan.FromDays(365))) throw new ArgumentException("Choose a countdown from 1 minute to 365 days.");
        p.ApplyTimer(now);
    }
    public static bool IsWebUrl(string value) => Uri.TryCreate(value.Trim(),UriKind.Absolute,out var uri) && (uri.Scheme=="http" || uri.Scheme=="https") && !string.IsNullOrEmpty(uri.Host) && string.IsNullOrEmpty(uri.UserInfo);
    public static IEnumerable<(string Name,string Text)> Fields(PresenceConfiguration p)
    {
        yield return ("Details",p.Details); yield return ("State",p.State);
        yield return ("Large image hover text",p.LargeImageText); yield return ("Small image hover text",p.SmallImageText);
        for(int i=0;i<p.Buttons.Count;i++) yield return ($"Button {i+1} label",p.Buttons[i].Label);
    }
}
public sealed record DiscordSession(string AccessToken,string RefreshToken,DateTimeOffset ExpiresAt)
{
    public bool NeedsRefresh(DateTimeOffset now) => ExpiresAt-now<=TimeSpan.FromDays(1);
}
public sealed record AppSettings
{
    public bool RestoreLastPresence { get; init; }
    public bool ClearPresenceOnQuit { get; init; }
    public bool ShareCrashReports { get; init; }
    public bool HideAfterApply { get; init; }
    public bool LaunchAtLogin { get; init; }
    public bool CloseToTray { get; init; } = true;
    public bool AllowHostedUploads { get; init; }
    public int RetentionDays { get; init; } = 30;
    public string Theme { get; init; } = "System";
}
public sealed record PresencePreset(Guid Id,string Name,PresenceConfiguration Configuration);
