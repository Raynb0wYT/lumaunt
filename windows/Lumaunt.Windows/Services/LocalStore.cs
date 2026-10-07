using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Text.Json;
using Lumaunt.Core;
namespace Lumaunt.Windows.Services;
public static class LocalStore
{
    public static string Root { get; private set; } = Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Lumaunt");
    public static bool IsolatedForChecks {get;private set;}
    internal static void IsolateChecks() {Root=Path.Combine(Path.GetTempPath(),"Lumaunt-check-"+Guid.NewGuid().ToString("N"));IsolatedForChecks=true;}
    public static string? RecoveryMessage { get; private set; }
    public static T Load<T>(string name,T fallback)
    {
        var path=Path.Combine(Root,name);
        if(!File.Exists(path)) return fallback;
        try { return JsonSerializer.Deserialize<T>(File.ReadAllBytes(path)) ?? fallback; }
        catch(JsonException)
        {
            File.Copy(path,path+"."+DateTime.UtcNow.ToString("yyyyMMddHHmmssfff")+".backup",false);
            RecoveryMessage="A saved data file could not be read. Its original contents were preserved in a backup; review your settings and presets.";
            return fallback;
        }
    }
    public static void Save<T>(string name,T value) => WriteAtomic(Path.Combine(Root,name),JsonSerializer.SerializeToUtf8Bytes(value));
    public static void WriteAtomic(string path,byte[] data)
    {
        Directory.CreateDirectory(Path.GetDirectoryName(path)!);
        var temporary=path+"."+Guid.NewGuid().ToString("N")+".tmp";
        try { File.WriteAllBytes(temporary,data); File.Move(temporary,path,true); }
        finally { if(File.Exists(temporary)) File.Delete(temporary); }
    }
}
// DPAPI is bound to the signed-in Windows user. No plaintext token files or SDK logs.
public sealed class SecretStore
{
    [StructLayout(LayoutKind.Sequential)] private struct Blob { public int Size; public IntPtr Data; }
    [DllImport("crypt32.dll",SetLastError=true,CharSet=CharSet.Unicode)] [return:MarshalAs(UnmanagedType.Bool)]
    private static extern bool CryptProtectData(ref Blob input,string description,IntPtr entropy,IntPtr reserved,IntPtr prompt,uint flags,out Blob output);
    [DllImport("crypt32.dll",SetLastError=true)] [return:MarshalAs(UnmanagedType.Bool)]
    private static extern bool CryptUnprotectData(ref Blob input,IntPtr description,IntPtr entropy,IntPtr reserved,IntPtr prompt,uint flags,out Blob output);
    [DllImport("kernel32.dll")] private static extern IntPtr LocalFree(IntPtr memory);
    private static byte[] Transform(byte[] bytes,bool encrypt)
    {
        var data=Marshal.AllocHGlobal(bytes.Length); var input=new Blob {Size=bytes.Length,Data=data}; Blob output=default;
        try
        {
            Marshal.Copy(bytes,0,data,bytes.Length);
            var success=encrypt ? CryptProtectData(ref input,"Lumaunt",IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,1,out output) : CryptUnprotectData(ref input,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,IntPtr.Zero,1,out output);
            if(!success) throw new System.ComponentModel.Win32Exception(Marshal.GetLastWin32Error(),"Windows could not access Lumaunt's protected credentials.");
            var result=new byte[output.Size];Marshal.Copy(output.Data,result,0,result.Length);return result;
        }
        finally
        {
            for(int i=0;i<bytes.Length;i++) Marshal.WriteByte(data,i,0);
            Marshal.FreeHGlobal(data); if(output.Data!=IntPtr.Zero) {for(int i=0;i<output.Size;i++) Marshal.WriteByte(output.Data,i,0);LocalFree(output.Data);}
        }
    }
    public T? Load<T>(string name)
    {
        var path=Path.Combine(LocalStore.Root,name+".protected");
        if(!File.Exists(path)) return default;
        var plain=Transform(File.ReadAllBytes(path),false);
        try { return JsonSerializer.Deserialize<T>(plain); } finally { Array.Clear(plain); }
    }
    public void Save<T>(string name,T value)
    {
        var plain=JsonSerializer.SerializeToUtf8Bytes(value);
        try { LocalStore.WriteAtomic(Path.Combine(LocalStore.Root,name+".protected"),Transform(plain,true)); } finally { Array.Clear(plain); }
    }
    public void Delete(string name)
    { var path=Path.Combine(LocalStore.Root,name+".protected"); if(File.Exists(path)) File.Delete(path); }
    public string ImageOwner()
    {
        var token=Load<string>("image-owner"); if(token!=null) return token;
        token=Convert.ToHexString(System.Security.Cryptography.RandomNumberGenerator.GetBytes(32));Save("image-owner",token);return token;
    }
}
