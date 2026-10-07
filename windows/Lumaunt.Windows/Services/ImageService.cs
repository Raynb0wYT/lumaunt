using System.IO;
using System.Net.Http;
using System.Net.Http.Json;
using System.Security.Cryptography;
using System.Text.Json;
using System.Windows;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using Lumaunt.Core;
using SkiaSharp;
namespace Lumaunt.Windows.Services;
public sealed record HostedImage(string Key,string Url,long ExpiresAt,string Hash);
public sealed class ImageService
{
    private readonly HttpClient client;
    private readonly SecretStore secrets=new();
    public List<HostedImage> Hosted {get;}=LocalStore.Load("hosted-images.json",new List<HostedImage>());
    public ImageService(HttpClient client) {this.client=client;}
    public void ClearUploadCache()
    {
        for(int i=0;i<Hosted.Count;i++) Hosted[i]=Hosted[i] with {Hash=""};
        Save();
    }
    public void ClearLocalImageCache()
    {
        var directory=Path.Combine(LocalStore.Root,"images");
        if(Directory.Exists(directory)) foreach(var file in Directory.EnumerateFiles(directory)) File.Delete(file);
        ClearUploadCache();
    }
    private void Save()=>LocalStore.Save("hosted-images.json",Hosted);
    public static byte[] Optimize(string path)
    {
        var info=new FileInfo(path);
        if(!info.Exists || info.Length<=0 || info.Length>32*1024*1024) throw new ArgumentException("Choose a readable image smaller than 32 MB.");
        using var input=new MemoryStream(DecodeWebP(File.ReadAllBytes(path)));
        var decoder=BitmapDecoder.Create(input,BitmapCreateOptions.PreservePixelFormat,BitmapCacheOption.OnLoad);
        if(decoder is not PngBitmapDecoder and not JpegBitmapDecoder) throw new ArgumentException("Choose a PNG, JPEG or WebP image.");
        var frame=decoder.Frames[0];
        if(frame.PixelWidth>4096 || frame.PixelHeight>4096) throw new ArgumentException("Images must be no larger than 4096 × 4096.");
        BitmapSource bitmap=frame;
        var scale=Math.Min(1,1024.0/Math.Max(frame.PixelWidth,frame.PixelHeight));
        if(scale<1) bitmap=new TransformedBitmap(frame,new ScaleTransform(scale,scale));
        BitmapEncoder encoder=decoder is JpegBitmapDecoder ? new JpegBitmapEncoder {QualityLevel=88} : new PngBitmapEncoder();
        encoder.Frames.Add(BitmapFrame.Create(bitmap));using var output=new MemoryStream();encoder.Save(output);
        if(output.Length>5*1024*1024) throw new ArgumentException("The optimized image exceeds the 5 MB upload limit.");
        return output.ToArray();
    }
    public static byte[] DecodeWebP(byte[] bytes)
    {
        if(bytes.Length<12 || System.Text.Encoding.ASCII.GetString(bytes,0,4)!="RIFF" || System.Text.Encoding.ASCII.GetString(bytes,8,4)!="WEBP") return bytes;
        using var stream=new MemoryStream(bytes);
        using var codec=SKCodec.Create(stream) ?? throw new ArgumentException("The WebP image could not be decoded.");
        if(codec.EncodedFormat!=SKEncodedImageFormat.Webp || codec.Info.Width>4096 || codec.Info.Height>4096) throw new ArgumentException("Images must be no larger than 4096 × 4096.");
        using var bitmap=SKBitmap.Decode(codec) ?? throw new ArgumentException("The WebP image could not be decoded.");
        using var image=SKImage.FromBitmap(bitmap);using var png=image.Encode(SKEncodedImageFormat.Png,100);
        return png.ToArray();
    }
    public static string Import(string path)
    {
        var bytes=Optimize(path);return StoreBytes(bytes);
    }
    private static string StoreBytes(byte[] bytes)
    {
        var directory=Path.Combine(LocalStore.Root,"images");Directory.CreateDirectory(directory);
        var hash=Convert.ToHexString(SHA256.HashData(bytes));
        var extension=bytes[0]==0x89 ? ".png" : ".jpg";var path=Path.Combine(directory,hash+extension);
        LocalStore.WriteAtomic(path,bytes);return path;
    }
    public static async Task<string> PasteAsync()
    {
        if(!Clipboard.ContainsImage()) throw new ArgumentException("The clipboard does not contain an image.");
        var bitmap=Clipboard.GetImage();if(bitmap==null || bitmap.PixelWidth>4096 || bitmap.PixelHeight>4096) throw new ArgumentException("Clipboard images must be no larger than 4096 × 4096.");
        bitmap.Freeze();
        return await Task.Run(()=>
        {
            BitmapSource source=bitmap;var scale=Math.Min(1,1024.0/Math.Max(bitmap.PixelWidth,bitmap.PixelHeight));
            if(scale<1) source=new TransformedBitmap(bitmap,new ScaleTransform(scale,scale));
            var encoder=new PngBitmapEncoder();encoder.Frames.Add(BitmapFrame.Create(source));using var output=new MemoryStream();encoder.Save(output);
            if(output.Length>5*1024*1024) throw new ArgumentException("Clipboard image exceeds 5 MB.");return StoreBytes(output.ToArray());
        });
    }
    public async Task<string> ResolveAsync(string value,AppSettings settings,CancellationToken cancellation)
    {
        value=value.Trim();if(value.Length==0) return "";
        if(PresenceValidation.IsWebUrl(value)) return value;
        if(!Path.IsPathRooted(value))
        {
            if(value.Contains(':')||value.Contains('/')||value.Contains('\\')) throw new ArgumentException("Use an image asset name, HTTP/HTTPS URL, or a selected local image.");
            return value;
        }
        if(!settings.AllowHostedUploads) throw new ArgumentException("Allow hosted image uploads in Settings before applying a local image, or use an existing URL.");
        var bytes=await Task.Run(()=>Optimize(value),cancellation);var hash=Convert.ToHexString(SHA256.HashData(bytes));
        var cached=Hosted.FirstOrDefault(i=>i.Hash==hash && i.ExpiresAt>DateTimeOffset.Now.AddMinutes(1).ToUnixTimeMilliseconds());
        if(cached!=null) return cached.Url;
        using var request=new HttpRequestMessage(HttpMethod.Post,"https://api.lumaunt.app/v2/images/upload");
        request.Headers.Add("X-Lumaunt-Owner",secrets.ImageOwner());request.Headers.Add("X-Lumaunt-Retention-Days",(new[]{7,30,90}.Contains(settings.RetentionDays)?settings.RetentionDays:30).ToString());
        request.Content=new ByteArrayContent(bytes);request.Content.Headers.ContentType=new(bytes[0]==0x89?"image/png":"image/jpeg");
        using var response=await client.SendAsync(request,cancellation);
        if(!response.IsSuccessStatusCode) throw new HttpRequestException($"Image upload failed (HTTP {(int)response.StatusCode}). Try again later.");
        using var json=JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellation));var item=json.RootElement;
        var url=item.GetProperty("url").GetString()!;var key=item.GetProperty("key").GetString()!;var expiry=item.GetProperty("expiresAt").GetInt64();
        if(string.IsNullOrWhiteSpace(key)||!Uri.TryCreate(url,UriKind.Absolute,out var uri)||uri.Scheme!="https"||expiry<=DateTimeOffset.Now.ToUnixTimeMilliseconds()) throw new InvalidDataException("Invalid image upload response.");
        Hosted.Add(new(key,url,expiry,hash));Save();return url;
    }
    public async Task DeleteAsync(HostedImage image,CancellationToken cancellation)
    {
        using var request=new HttpRequestMessage(HttpMethod.Post,"https://api.lumaunt.app/v2/images/delete");request.Headers.Add("X-Lumaunt-Owner",secrets.ImageOwner());request.Content=JsonContent.Create(new {key=image.Key});
        using var response=await client.SendAsync(request,cancellation);
        if(!response.IsSuccessStatusCode) throw new HttpRequestException("The hosted image could not be deleted. Try again later.");
        Hosted.Remove(image);Save();
    }
}
