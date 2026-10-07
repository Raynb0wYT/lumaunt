using System.IO;
using System.Text;
using System.Text.Json;
using Sentry;
using Sentry.Extensibility;
using Sentry.Protocol;
using Sentry.Protocol.Envelopes;
namespace Lumaunt.Windows.Services;
internal static class CrashReportingChecks
{
    internal static async Task RunAsync()
    {
        if(!LocalStore.IsolatedForChecks) throw new InvalidOperationException("Crash checks require isolated storage.");
        if(CrashReporting.Enabled||SentrySdk.IsEnabled) throw new InvalidOperationException("Crash reporting started without consent.");
        var transport=new CapturingTransport();
        try
        {
            CrashReporting.Configure(true,transport);
            var evt=new SentryEvent() {Message="secret-message",ServerName="secret-machine",User=new SentryUser {Username="secret-account",Id="secret-user"},SentryExceptions=new[]{new SentryException {Type="InvalidOperationException",Value="secret-value",Stacktrace=new SentryStackTrace {Frames=new List<SentryStackFrame> {new() {Function="Lumaunt.Windows.MainWindow.Test",FileName="secret-path",ContextLine="secret-content"}}}}}};
            evt.SetTag("secret-tag","secret-tag-value");evt.SetExtra("secret-extra","secret-extra-value");evt.AddBreadcrumb(new Breadcrumb("secret-breadcrumb","default",null,null,BreadcrumbLevel.Info));
            SentrySdk.CaptureEvent(evt);await SentrySdk.FlushAsync(TimeSpan.FromSeconds(5));
            if(transport.Body==null||transport.Body.Contains("secret-",StringComparison.Ordinal)) throw new InvalidOperationException("Sentry envelope retained sensitive test content.");
            if(!transport.Body.Contains("InvalidOperationException")||!transport.Body.Contains("Lumaunt.Windows.MainWindow.Test")) throw new InvalidOperationException("Sentry envelope lost structural crash diagnostics.");
        }
        finally {CrashReporting.Configure(false);}
        if(CrashReporting.Enabled||SentrySdk.IsEnabled) throw new InvalidOperationException("Sentry did not stop after opt-out.");
    }
    private sealed class CapturingTransport : ITransport
    {
        public string? Body;
        public async Task SendEnvelopeAsync(Envelope envelope,CancellationToken cancellationToken=default)
        {using var output=new MemoryStream();await envelope.SerializeAsync(output,null,cancellationToken);Body=Encoding.UTF8.GetString(output.ToArray());}
    }
}
