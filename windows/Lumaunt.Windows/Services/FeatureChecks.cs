using System.IO;
using System.Net;
using System.Net.Http;
using System.Text.Json;
using Lumaunt.Core;
using SkiaSharp;
namespace Lumaunt.Windows.Services;
// Runs only with --check-windows-features in an isolated temporary data folder.
internal static class FeatureChecks
{
    public static async Task RunAsync()
    {
        if(!LocalStore.IsolatedForChecks) throw new InvalidOperationException("Checks require isolated storage.");
        Directory.CreateDirectory(LocalStore.Root);
        var crashFile=Path.Combine(LocalStore.Root,"last-crash.json");LocalCrashReports.Record(new InvalidOperationException("test-secret"));
        if(File.Exists(crashFile)) throw new InvalidOperationException("Crash report opt-out was ignored.");
        LocalStore.Save("settings.json",new AppSettings {ShareCrashReports=true});LocalCrashReports.Record(new InvalidOperationException("test-secret"));
        if(!File.Exists(crashFile)||File.ReadAllText(crashFile).Contains("test-secret")) throw new InvalidOperationException("Local crash report privacy check failed.");
        LocalStore.Save("settings.json",new AppSettings());
        var fake=new ImageApi();using var client=new HttpClient(fake);var images=new ImageService(client);
        if(await images.ResolveAsync("  ",new AppSettings {AllowHostedUploads=true},CancellationToken.None)!="" || fake.Uploads!=0)
            throw new InvalidOperationException("An empty image triggered an upload.");
        int i=0;
        foreach(var days in new[]{7,30,90})
        {
            var path=Path.Combine(LocalStore.Root,$"fixture-{i}.png");using var bitmap=new SKBitmap(i==0?2048:16,16);bitmap.Erase(i==0?SKColors.Cyan:i==1?SKColors.Red:SKColors.Green);
            using var image=SKImage.FromBitmap(bitmap);using var data=image.Encode(SKEncodedImageFormat.Png,100);File.WriteAllBytes(path,data.ToArray());
            var optimized=ImageService.Optimize(path);using var decoded=SKBitmap.Decode(optimized);
            if(decoded.Width>1024||decoded.Height>1024) throw new InvalidOperationException("Image optimization exceeds bounds.");
            if(i==0)
            {
                try {await images.ResolveAsync(path,new AppSettings(),CancellationToken.None);throw new InvalidOperationException("Upload consent was bypassed.");}
                catch(ArgumentException) {if(fake.Uploads!=0) throw new InvalidOperationException("Disallowed upload reached the API.");}
            }
            var settings=new AppSettings {AllowHostedUploads=true,RetentionDays=days};
            var url=await images.ResolveAsync(path,settings,CancellationToken.None);
            var repeated=await images.ResolveAsync(path,settings,CancellationToken.None);
            if(url!=repeated||fake.Uploads!=i+1||fake.Days.Last()!=days) throw new InvalidOperationException("Retention or image cache check failed.");
            i++;
        }
        var keys=images.Hosted.Select(i=>i.Key).ToArray();var uploadCount=fake.Uploads;
        images.ClearUploadCache();
        if(!images.Hosted.Select(i=>i.Key).SequenceEqual(keys)||images.Hosted.Any(i=>i.Hash.Length>0)||fake.Uploads!=uploadCount) throw new InvalidOperationException("Clearing upload cache lost ownership or made a request.");
        var reloaded=new ImageService(client);if(!reloaded.Hosted.Select(i=>i.Key).SequenceEqual(keys)) throw new InvalidOperationException("Cache clearing did not retain persisted ownership records.");
        await images.ResolveAsync(Path.Combine(LocalStore.Root,"fixture-0.png"),new AppSettings {AllowHostedUploads=true},CancellationToken.None);
        if(fake.Uploads!=uploadCount+1) throw new InvalidOperationException("Cleared upload cache was reused.");
        var record=images.Hosted[0];fake.AllowDelete=false;
        try {await images.DeleteAsync(record,CancellationToken.None);throw new InvalidOperationException("Rejected deletion was accepted.");}
        catch(HttpRequestException) {if(!images.Hosted.Contains(record)) throw new InvalidOperationException("Rejected deletion removed the local ownership record.");}
        fake.AllowDelete=true;await images.DeleteAsync(record,CancellationToken.None);
        if(images.Hosted.Contains(record)) throw new InvalidOperationException("Deleted upload stayed cached.");
        var cacheDirectory=Path.Combine(LocalStore.Root,"images");Directory.CreateDirectory(cacheDirectory);
        var cachedArtwork=Path.Combine(cacheDirectory,"cached.png");File.Copy(Path.Combine(LocalStore.Root,"fixture-0.png"),cachedArtwork,true);
        var retainedKeys=images.Hosted.Select(i=>i.Key).ToArray();var requestsBeforeClear=fake.Uploads;
        images.ClearLocalImageCache();
        if(File.Exists(cachedArtwork)||!File.Exists(Path.Combine(LocalStore.Root,"fixture-0.png"))||!images.Hosted.Select(i=>i.Key).SequenceEqual(retainedKeys)||images.Hosted.Any(i=>i.Hash.Length>0)||fake.Uploads!=requestsBeforeClear) throw new InvalidOperationException("Local cache clearing lost ownership, touched files outside the managed cache, or made an upload.");
        var preset=new PresencePreset(Guid.NewGuid(),"Round trip",new PresenceConfiguration {CustomStartTime=DateTimeOffset.Now.AddHours(-1),Buttons=new[]{new PresenceButton("First","https://example.com/first"),new PresenceButton("Second","https://example.com/second")}});
        LocalStore.Save("presets.json",new[]{preset});var loaded=LocalStore.Load("presets.json",Array.Empty<PresencePreset>()).Single();
        if(loaded.Configuration.CustomStartTime!=preset.Configuration.CustomStartTime || !loaded.Configuration.Buttons.SequenceEqual(preset.Configuration.Buttons)) throw new InvalidOperationException("Preset round-trip changed timer or button order.");
    }
    private sealed class ImageApi : HttpMessageHandler
    {
        public int Uploads;public List<int> Days=new();public bool AllowDelete;
        protected override Task<HttpResponseMessage> SendAsync(HttpRequestMessage request,CancellationToken cancellation)
        {
            if(request.Headers.GetValues("X-Lumaunt-Owner").Single().Length!=64) throw new InvalidOperationException("Missing installation ownership token.");
            if(request.RequestUri!.AbsolutePath.EndsWith("/delete")) return Task.FromResult(new HttpResponseMessage(AllowDelete?HttpStatusCode.OK:HttpStatusCode.Forbidden) {Content=new StringContent("{}")});
            var days=int.Parse(request.Headers.GetValues("X-Lumaunt-Retention-Days").Single());Days.Add(days);Uploads++;
            if(request.Content!.Headers.ContentType?.MediaType!="image/png") throw new InvalidOperationException("Invalid upload content type.");
            return Task.FromResult(new HttpResponseMessage(HttpStatusCode.OK) {Content=new StringContent(JsonSerializer.Serialize(new {key=$"managed-images/test-{Uploads}.png",url=$"https://images.example.com/test-{Uploads}.png",expiresAt=DateTimeOffset.Now.AddDays(days).ToUnixTimeMilliseconds()}))});
        }
    }
}
