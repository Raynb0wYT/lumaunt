using Lumaunt.Core;
var now = DateTimeOffset.Parse("2026-10-03T12:00:00Z");
void Check(bool value, string name) { if (!value) throw new Exception(name); Console.WriteLine($"PASS: {name}"); }
void Reject(Action action, string name) { try { action(); } catch (ArgumentOutOfRangeException) { Console.WriteLine($"PASS: {name}"); return; } throw new Exception(name); }
var elapsed = new PresenceConfiguration().ApplyTimer(now);
Check(elapsed.Start == now && elapsed.End == null, "Elapsed timer starts on Apply");
var past = now.AddHours(-2);
Check((new PresenceConfiguration { CustomStartTime = past }).ApplyTimer(now).Start == past, "Custom start is preserved");
Reject(() => (new PresenceConfiguration { CustomStartTime = now.AddSeconds(1) }).ApplyTimer(now), "Future start rejected");
Reject(() => (new PresenceConfiguration { CustomStartTime = DateTimeOffset.UnixEpoch.AddSeconds(-1) }).ApplyTimer(now), "Pre-epoch start rejected");
var countdown = (new PresenceConfiguration { TimerMode = TimerMode.Countdown, DisableWhenTimerEnds = true }).ApplyTimer(now);
Check(countdown.Start == null && countdown.End == now.AddHours(1), "Countdown uses end timestamp");
Check(!countdown.ShouldDisable(now.AddMinutes(59)) && countdown.ShouldDisable(now.AddHours(1)), "Auto-disable triggers exactly at expiry");
var restored = (new PresenceConfiguration { TimerMode = TimerMode.Countdown }).ApplyTimer(now, now.AddMinutes(7));
Check(restored.End == now.AddMinutes(7) && !restored.ShouldDisable(now.AddHours(1)), "Restoration preserves expiry and opt-out");
Reject(() => (new PresenceConfiguration { TimerMode = TimerMode.Countdown, CountdownDuration = TimeSpan.Zero }).ApplyTimer(now), "Nonpositive duration rejected");

foreach(var cluster in new[]{"😀","🇺🇸","e\u0301","👨‍👩‍👧‍👦"})
{
    var text=string.Concat(Enumerable.Repeat(cluster,129));
    Check(PresenceText.TrimToLimit(text,128)==string.Concat(Enumerable.Repeat(cluster,128)),"Text limit preserves graphemes: "+cluster);
    Check(PresenceText.TrimToLimit(text,32)==string.Concat(Enumerable.Repeat(cluster,32)),"Button limit preserves graphemes: "+cluster);
}
Check(!new AppliedPresence(countdown.Configuration,null,null).CanRestore(now),"Missing auto-disable deadline does not restart countdown");
Check(!countdown.CanRestore(now.AddHours(1)),"Expired auto-disable countdown is not restored");
Check(countdown.CanRestore(now.AddMinutes(59)),"Future auto-disable deadline can restore");
Check(elapsed.CanRestore(now),"Elapsed restoration remains allowed");

var moderationCases=System.Text.Json.JsonSerializer.Deserialize<List<FilterCase>>(File.ReadAllBytes(Path.Combine(AppContext.BaseDirectory,"ModerationCases.json")))!;
foreach(var c in moderationCases)
{
    var decision=ContentFilter.Evaluate(c.Text);
    Check(decision.BlockedCategory==null && (c.Category==null?decision.ReviewCategories.Count==0:decision.ReviewCategories.Contains(c.Category)),"Mac moderation parity: "+c.Text);
}
Check(ContentFilter.Evaluate("n1gg3r").BlockedCategory=="hatefulConduct","Obfuscated slur is blocked locally");
Check(ContentFilter.Evaluate("raccoon watching").BlockedCategory==null,"Substring slur false positive avoided");
Check(!new DiscordSession("access","refresh",now.AddDays(2)).NeedsRefresh(now),"Valid access token can restore without rotation");
Check(new DiscordSession("access","refresh",now.AddHours(23)).NeedsRefresh(now),"Near-expiry session uses refresh token");
Check(!PresenceValidation.IsWebUrl("javascript:alert(1)")&&!PresenceValidation.IsWebUrl("https://user:password@example.com")&&PresenceValidation.IsWebUrl("https://example.com"),"Unsafe button schemes and embedded credentials rejected");
var http=new FakeModeration();var service=new ModerationService(new HttpClient(http));
await service.CheckAsync(new PresenceConfiguration {Details="kill the boss"},CancellationToken.None);
Check(http.Calls==0,"Harmless text stays local");
await service.CheckAsync(new PresenceConfiguration {Details="I'll kill you"},CancellationToken.None);
Check(http.Calls==1,"Context-sensitive content is reviewed remotely");
http.Mode="violation";
await MustRejectAsync(()=>service.CheckAsync(new PresenceConfiguration {Details="I'll kill you"},CancellationToken.None),"Confirmed violation is blocked");
http.Mode="malformed";
await MustRejectAsync(()=>service.CheckAsync(new PresenceConfiguration {Details="I'll kill you"},CancellationToken.None),"Malformed moderation response fails closed");
http.Mode="wrong-category";
await MustRejectAsync(()=>service.CheckAsync(new PresenceConfiguration {Details="I'll kill you"},CancellationToken.None),"Mismatched moderation category fails closed");
http.Mode="unavailable";
await MustRejectAsync(()=>service.CheckAsync(new PresenceConfiguration {Details="I'll kill you"},CancellationToken.None),"Unavailable moderation fails closed");
async Task MustRejectAsync(Func<Task> action,string name)
{try {await action();} catch(Exception error) when(error is ArgumentException or System.Text.Json.JsonException or InvalidDataException or HttpRequestException) {Console.WriteLine("PASS: "+name);return;} throw new Exception(name);}
record FilterCase(string Text,string? Category);
sealed class FakeModeration : HttpMessageHandler
{
    public int Calls;public string Mode="contextual";
    protected override async Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancellation)
    {
        Calls++;using var body=System.Text.Json.JsonDocument.Parse(await request.Content!.ReadAsStringAsync(cancellation));
        var category=body.RootElement.GetProperty("suspectedCategory").GetString();
        if(Mode=="unavailable") return new(System.Net.HttpStatusCode.ServiceUnavailable);
        var content=Mode=="malformed"?"{}":System.Text.Json.JsonSerializer.Serialize(new {success=true,category=Mode=="wrong-category"?"harassment":category,classification=Mode=="violation"?"violation":"contextual",confirmed=Mode=="violation"});
        return new(System.Net.HttpStatusCode.OK) {Content=new StringContent(content)};
    }
}
