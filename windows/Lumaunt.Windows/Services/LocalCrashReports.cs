using System.Runtime.InteropServices;
using Lumaunt.Core;
namespace Lumaunt.Windows.Services;
// No network sender. Only structural diagnostics are retained after explicit opt-in.
public sealed record LocalCrashReport(DateTimeOffset Time,string ExceptionType,int ErrorCode,string Version,string OS,string Architecture);
internal static class LocalCrashReports
{
    public static void Record(Exception error)
    {
        try
        {
            if(!LocalStore.Load("settings.json",new AppSettings()).ShareCrashReports) return;
            var report=new LocalCrashReport(DateTimeOffset.UtcNow,error.GetType().Name,error.HResult,typeof(App).Assembly.GetName().Version?.ToString()??"",Environment.OSVersion.VersionString,RuntimeInformation.ProcessArchitecture.ToString());
            LocalStore.Save("last-crash.json",report);
        }
        catch { /* Reporting must never replace or hide the original failure. */ }
    }
}
