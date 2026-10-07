using System.IO;
using System.Security.Cryptography;
using Lumaunt.Core;
namespace Lumaunt.Windows.Services;
// Uses only a uniquely named test folder and fake credentials; never reads a real session.
internal static class StoreDataChecks
{
    private sealed record Sample(string ImagePath,string Hash,string Note);
    internal static void Run(string mode,string token)
    {
        if(!Guid.TryParseExact(token,"N",out _))throw new ArgumentException("A unique test identifier is required.");
        var name="store-qa-"+token;
        var directory=Path.Combine(LocalStore.Root,name);
        if(mode=="seed")
        {
            if(Directory.Exists(directory))throw new InvalidOperationException("Test folder already exists; leave it intact.");
            Directory.CreateDirectory(directory);
            using var bitmap=new SkiaSharp.SKBitmap(16,16);bitmap.Erase(SkiaSharp.SKColors.Cyan);
            using var image=SkiaSharp.SKImage.FromBitmap(bitmap);using var data=image.Encode(SkiaSharp.SKEncodedImageFormat.Png,100);
            var path=Path.Combine(directory,"image.png");File.WriteAllBytes(path,data.ToArray());
            LocalStore.Save(name+"/sample.json",new Sample(path,Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(path))),"settings/preset persistence fixture"));
            LocalStore.Save(name+"/settings.json",new AppSettings{RestoreLastPresence=true,AllowHostedUploads=false,RetentionDays=7});
            new SecretStore().Save(name+"/fake-session","test-only-"+token);
        }
        else if(mode=="verify")
        {
            var sample=LocalStore.Load<Sample?>(name+"/sample.json",null)??throw new InvalidOperationException("Sample data missing after install/update.");
            if(!File.Exists(sample.ImagePath) || Convert.ToHexString(SHA256.HashData(File.ReadAllBytes(sample.ImagePath)))!=sample.Hash || ImageService.Optimize(sample.ImagePath).Length==0)throw new InvalidOperationException("Stored image path/content failed.");
            var settings=LocalStore.Load(name+"/settings.json",new AppSettings());
            if(!settings.RestoreLastPresence || settings.AllowHostedUploads || settings.RetentionDays!=7)throw new InvalidOperationException("Saved settings changed.");
            if(new SecretStore().Load<string>(name+"/fake-session")!="test-only-"+token)throw new InvalidOperationException("DPAPI data not readable after install/update.");
        }
        else if(mode=="clean") {if(Directory.Exists(directory))Directory.Delete(directory,true);}
        else throw new ArgumentException("Unknown sample-data operation.");
    }
}
