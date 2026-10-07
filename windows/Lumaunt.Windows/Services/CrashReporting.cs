using System.Diagnostics;
using System.Runtime.InteropServices;
using Sentry;
using Sentry.Extensibility;
using Sentry.Protocol;
namespace Lumaunt.Windows.Services;
internal static class CrashReporting
{
    private static IDisposable? sdk;
    private static volatile bool enabled;
    internal static bool Enabled=>enabled;
    internal static void Configure(bool optIn,ITransport? testTransport=null)
    {
        if(!optIn) {enabled=false;sdk?.Dispose();sdk=null;return;}
        if(LocalStore.IsolatedForChecks&&testTransport==null) return;
        if(enabled) return;
        if(testTransport==null && string.IsNullOrWhiteSpace(CrashReportingConfig.Dsn)) throw new InvalidOperationException("The Sentry project DSN has not been configured.");
        sdk=SentrySdk.Init(options=>
        {
            options.Dsn=testTransport==null?CrashReportingConfig.Dsn:"https://public@example.invalid/1";
            options.Transport=testTransport;options.Debug=false;options.SendDefaultPii=false;options.IsEnvironmentUser=false;
            options.AutoSessionTracking=false;options.MaxBreadcrumbs=0;options.SendClientReports=false;options.EnableLogs=false;
            options.TracesSampleRate=0;options.EnableBackpressureHandling=false;
            options.DisableDiagnosticSourceIntegration();options.DisableSystemDiagnosticsMetricsIntegration();
            options.DisableAppDomainUnhandledExceptionCapture();options.DisableUnobservedTaskExceptionCapture();options.DisableWinUiUnhandledExceptionIntegration();
            options.DisableAppDomainProcessExitFlush();options.AttachStacktrace=false;options.ServerName="";options.CacheDirectoryPath=null;
            options.SetBeforeBreadcrumb(_=>null);options.SetBeforeSendLog(_=>null);options.SetBeforeSendMetric(_=>null);
            options.SetBeforeSend(evt=>enabled?Scrub(evt):null);
        });
        enabled=true;
    }
    internal static void Capture(Exception error)
    {
        if(!enabled) return;
        try
        {
            var frames=new StackTrace(error,false).GetFrames()?.Select(f=>f.GetMethod()).Where(m=>m!=null).Select(m=>new SentryStackFrame {Function=m!.DeclaringType?.FullName+"."+m.Name,Module=m.DeclaringType?.Assembly.GetName().Name}).Reverse().ToList();
            SentrySdk.CaptureEvent(new SentryEvent {Level=SentryLevel.Fatal,SentryExceptions=new[]{new SentryException {Type=error.GetType().Name,Stacktrace=frames==null?null:new SentryStackTrace {Frames=frames}}}});
            SentrySdk.FlushAsync(TimeSpan.FromSeconds(2)).GetAwaiter().GetResult();
        } catch { }
    }
    internal static SentryEvent Scrub(SentryEvent original)
    {
        // Rebuild from a strict allowlist. No messages, user, requests, breadcrumbs,
        // tags, extras, thread dumps, machine names, local paths or exception values.
        var safe=new SentryEvent {Level=original.Level,Release="lumaunt-windows@"+typeof(App).Assembly.GetName().Version,Environment="windows-preview",ServerName=null};
        safe.SentryExceptions=original.SentryExceptions?.Select(ex=>new SentryException
        {
            Type=ex.Type?.Split('.').Last(),
            Stacktrace=ex.Stacktrace==null?null:new SentryStackTrace {Frames=ex.Stacktrace.Frames.Where(f=>f.Function?.StartsWith("Lumaunt.",StringComparison.Ordinal)==true||f.Function?.StartsWith("System.",StringComparison.Ordinal)==true).Select(f=>new SentryStackFrame {Function=f.Function}).ToList()}
        }).ToArray();
        safe.Contexts.OperatingSystem.Name="Windows";safe.Contexts.OperatingSystem.Version=System.Environment.OSVersion.Version.ToString();
        safe.Contexts.Runtime.Name=".NET";safe.Contexts.Runtime.Version=System.Environment.Version.ToString();safe.Contexts.Device.Architecture=RuntimeInformation.ProcessArchitecture.ToString();
        return safe;
    }
}
