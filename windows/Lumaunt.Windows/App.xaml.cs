using System.IO;
using System.Security.Principal;
using System.Windows;
using Lumaunt.Core;
using Lumaunt.Windows.Discord;
using Lumaunt.Windows.Services;
namespace Lumaunt.Windows;
public partial class App : Application
{
    private Mutex? instance;
    protected override async void OnStartup(StartupEventArgs e)
    {
        if(e.Args.Length==3 && e.Args[0]=="--check-store-data")
        {
            var report=Path.Combine(Path.GetTempPath(),"lumaunt-store-data-check.txt");
            try{StoreDataChecks.Run(e.Args[1],e.Args[2]);File.WriteAllText(report,"PASS: "+e.Args[1]+" sample settings, absolute image path and fake DPAPI session; packaged="+LoginStartup.IsPackaged);Shutdown(0);}
            catch(Exception error){File.WriteAllText(report,"FAIL: "+error);Shutdown(1);}
            return;
        }
        if(e.Args.Contains("--check-packaged-startup"))
        {
            var report=Path.Combine(Path.GetTempPath(),"lumaunt-packaged-startup-check.txt");
            try{await LoginStartupChecks.RunPackagedAsync();File.WriteAllText(report,"PASS: installed package identity; real StartupTask enable/disable; registry startup untouched; original task state restored. No Discord connection or publishing performed.");Shutdown(0);}
            catch(Exception error){File.WriteAllText(report,"FAIL: "+error);Shutdown(1);}
            return;
        }
        if(e.Args.Contains("--check-discord-runtime") || e.Args.Contains("--check-windows-features"))
        {
            var features=e.Args.Contains("--check-windows-features");
            var report=Path.Combine(LoginStartup.IsPackaged?Path.GetTempPath():AppContext.BaseDirectory,features?"windows-feature-check.txt":"discord-runtime-check.txt");
            try
            {
                if(features) LocalStore.IsolateChecks();
                using var connection=new DiscordConnection(Dispatcher);connection.VerifyRuntime();
                if(features)
                {
                    var secrets=new SecretStore();var name="runtime-check-"+Guid.NewGuid().ToString("N");
                    try
                    {
                        var fake=new DiscordSession("test-access","test-refresh",DateTimeOffset.Now.AddDays(3));secrets.Save(name,fake);
                        var raw=File.ReadAllBytes(Path.Combine(LocalStore.Root,name+".protected"));
                        if(System.Text.Encoding.UTF8.GetString(raw).Contains("test-access") || secrets.Load<DiscordSession>(name)!=fake) throw new InvalidOperationException("Protected storage round-trip failed.");
                    } finally {secrets.Delete(name);}
                    var imageFile=Path.Combine(Path.GetTempPath(),"lumaunt-image-check-"+Guid.NewGuid().ToString("N")+".webp");
                    try
                    {
                        using var bitmap=new SkiaSharp.SKBitmap(16,16);bitmap.Erase(SkiaSharp.SKColors.Cyan);
                        using var image=SkiaSharp.SKImage.FromBitmap(bitmap);using var data=image.Encode(SkiaSharp.SKEncodedImageFormat.Webp,90);File.WriteAllBytes(imageFile,data.ToArray());
                        var optimized=ImageService.Optimize(imageFile);if(optimized.Length==0 || optimized[0]!=0x89) throw new InvalidOperationException("WebP optimization failed.");
                    } finally {if(File.Exists(imageFile)) File.Delete(imageFile);}
                    await LoginStartupChecks.RunAsync();await FeatureChecks.RunAsync();await CrashReportingChecks.RunAsync();
                    var dpiVerified=DpiChecks.Verify();var window=new MainWindow();window.VerifyThemes();window.VerifyPresentation();window.VerifyCountdownSteppers();dpiVerified &= DpiChecks.Verify();
                    File.WriteAllText(report,"PASS: "+(dpiVerified?"actual PerMonitorV2 DPI context before/after WPF window initialization; ":"DPI validation skipped in headless Session0; ")+"startup enable/disable, Windows user/policy overrides, refused/failed requests with isolated fake backend; SDK lifecycle (five create/teardown cycles, stale-generation rejection, stopped timers, idempotent teardown), Unicode editor limits, incomplete preset save/load with Apply rejection, countdown steppers, Windows DPAPI encrypted round-trip, WebP decode/optimization, all WPF pages and resources, dark/light settings initialization, responsive layouts, button add/remove/reorder, tray initialization, upload consent/retention/cache/deletion with isolated fake API, Sentry opt-in/opt-out and scrubbed envelope with fake transport. No OAuth or publishing performed.\n");
                    window.RequestQuit();
                }
                else File.WriteAllText(report,"PASS: WPF managed/native SDK loading, callback registration, client creation and explicit teardown. No OAuth or session persistence.\n");
                Shutdown(0);
            }
            catch(Exception error)
            {File.WriteAllText(report,"FAIL: "+error.GetType().Name+"\n"+error.Message+"\n"+error.StackTrace);Shutdown(1);}
            if(features && LocalStore.IsolatedForChecks && Directory.Exists(LocalStore.Root)) Directory.Delete(LocalStore.Root,true);
            return;
        }
        DispatcherUnhandledException+=(_,args)=>{LocalCrashReports.Record(args.Exception);CrashReporting.Capture(args.Exception);};
        AppDomain.CurrentDomain.UnhandledException+=(_,args)=>{if(args.ExceptionObject is Exception error) {LocalCrashReports.Record(error);CrashReporting.Capture(error);}};
        base.OnStartup(e);
        instance=new Mutex(true,"Local\\LumauntWindows-"+WindowsIdentity.GetCurrent().User!.Value,out var created);
        if(!created) {MessageBox.Show("Lumaunt is already running. Open it from the system tray.","Lumaunt");Shutdown();return;}
        try
        {
            CrashReporting.Configure(LocalStore.Load("settings.json",new AppSettings()).ShareCrashReports);
            MainWindow=new MainWindow();
            SessionEnding+=(_,_)=>((MainWindow)MainWindow).RequestQuit();
            MainWindow.Show();
            if(e.Args.Contains("--tray")) MainWindow.Hide();
        }
        catch(Exception error)
        {MessageBox.Show("Lumaunt could not start. Check access to its saved data folder.\n"+error.GetType().Name,"Lumaunt");Shutdown(1);}
    }
    protected override void OnExit(ExitEventArgs e)
    {CrashReporting.Configure(false);instance?.Dispose();base.OnExit(e);}
}
