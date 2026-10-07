using System.IO;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Threading;
using Lumaunt.Core;
using Lumaunt.Windows.Services;
namespace Lumaunt.Windows.Discord;

public sealed class DiscordConnection : IDisposable
{
    private const ulong ApplicationId=1553944326076375230;
    private readonly Dispatcher dispatcher;
    private readonly DispatcherTimer callbackTimer, refreshTimer;
    private readonly SecretStore secrets=new();
    private readonly StatusCallback statusCallback;
    private readonly AuthCallback authCallback;
    private readonly UserCallback userCallback;
    private readonly PresenceCallback presenceCallback;
    private ulong generation;
    private bool initialized, disposed, refreshing;
    private bool openOAuthSuccessPage;
    private const string OAuthSuccessPage="https://lumaunt.app/auth/discord/";
    private DiscordSession? session;
    private TaskCompletionSource<bool>? pending;
    private long operationId;
    public ulong Generation => generation;
    public bool Available {get;}
    public bool Connecting {get;private set;}
    public bool Ready {get;private set;}
    public string Status {get;private set;}="Discord disconnected";
    public string DisplayName {get;private set;}="";
    public string Username {get;private set;}="";
    public string AvatarUrl {get;private set;}="";
    public event Action? Changed;
    public DiscordConnection(Dispatcher dispatcher)
    {
        this.dispatcher=dispatcher;
        Available=File.Exists(Path.Combine(AppContext.BaseDirectory,"lumaunt_discord.dll"));
        statusCallback=(status,_)=>
        {
            var epoch=ConnectionGeneration();
            dispatcher.BeginInvoke(()=>
            {
                if(!Current(epoch)) return;
                // The SDK reports Disconnected immediately after creation, before OAuth.
                if(status==0 && Connecting && !Ready) return;
                var wasReady=Ready;
                Ready=status==2; Connecting=status==1;
                Status=status switch {2=>"Discord connected",1=>"Connecting to Discord…",0=>"Discord disconnected",_=>"Discord connection error"};
                if(!Ready && wasReady) FailPending("Discord connection was lost.");
                Changed?.Invoke();
                if(Ready) GetCurrentUser(userCallback!,IntPtr.Zero);
            });
        };
        authCallback=(success,message,access,refresh,expires)=>
        {
            var epoch=ConnectionGeneration();
            var failure=Marshal.PtrToStringUTF8(message)??"";
            var accessToken=Marshal.PtrToStringUTF8(access)??"";
            var refreshToken=Marshal.PtrToStringUTF8(refresh)??"";
            dispatcher.BeginInvoke(()=>
            {
                if(!Current(epoch)) return;
                refreshing=false;
                if(success==0 || accessToken.Length==0 || refreshToken.Length==0 || expires<=0)
                {
                    StopRuntime();
                    if(failure.Contains("invalid_grant",StringComparison.OrdinalIgnoreCase))
                    {
                        session=null;
                        try {secrets.Delete("discord-session");} catch {Status="Sign-in expired. Windows could not remove saved credentials.";Changed?.Invoke();return;}
                        Status="Saved Discord sign-in expired. Connect again.";
                    }
                    else Status="Discord authorization failed. Try Connect again.";
                    Changed?.Invoke();return;
                }
                session=new(accessToken,refreshToken,DateTimeOffset.Now.AddSeconds(expires));
                try {secrets.Save("discord-session",session);}
                catch {Status="Connected, but Windows could not save this session.";Changed?.Invoke();}
                refreshTimer!.Start();
                if(TakeOAuthSuccessPageRequest())
                    try {Process.Start(new ProcessStartInfo(OAuthSuccessPage) {UseShellExecute=true});}
                    catch { /* Browser launch failure must not undo a successful Discord login. */ }
            });
        };
        userCallback=(name,username,avatar,_)=>
        {
            var epoch=ConnectionGeneration();
            var display=Marshal.PtrToStringUTF8(name)??"";var account=Marshal.PtrToStringUTF8(username)??"";var url=Marshal.PtrToStringUTF8(avatar)??"";
            dispatcher.BeginInvoke(()=> {if(!Current(epoch)||!Ready) return; DisplayName=display;Username=account;AvatarUrl=url;Changed?.Invoke();});
        };
        presenceCallback=(success,_,context)=>
        {
            var id=context.ToInt64();
            dispatcher.BeginInvoke(()=>
            {
                if(pending==null || id!=operationId) return;
                var completion=pending;pending=null;
                if(success!=0 && Ready) completion.TrySetResult(true);
                else completion.TrySetException(new InvalidOperationException("Discord did not accept the presence. Try again."));
            });
        };
        callbackTimer=new DispatcherTimer(TimeSpan.FromMilliseconds(16),DispatcherPriority.Background,(_,_)=>
        {
            if(!initialized||disposed) return;
            try {RunCallbacks();} catch(Exception error) when(IsLoadError(error)) {LoadFailed();}
        },dispatcher);callbackTimer.Stop();
        refreshTimer=new DispatcherTimer(TimeSpan.FromMinutes(1),DispatcherPriority.Background,(_,_)=>
        {
            if(Ready && session!=null && !refreshing && session.ExpiresAt-DateTimeOffset.Now<=TimeSpan.FromMinutes(5))
            {refreshing=true;LoginRefresh(ApplicationId,session.RefreshToken,authCallback);}
        },dispatcher);refreshTimer.Stop();
    }
    private bool Current(ulong epoch)=>!disposed && initialized && epoch==generation;
    private void StartRuntime()
    {
        if(!Available) throw new DllNotFoundException();
        if(initialized) StopRuntime();
        SetStatusCallback(statusCallback,IntPtr.Zero);Initialize(ApplicationId);generation=ConnectionGeneration();initialized=true;
        Ready=false;Connecting=true;Status="Connecting to Discord…";callbackTimer.Start();Changed?.Invoke();
    }
    public void RestoreSession()
    {
        dispatcher.VerifyAccess();
        if(!Available||disposed||initialized) return;
        try
        {
            session=secrets.Load<DiscordSession>("discord-session");
            if(session==null) return;
            StartRuntime();
            if(session.NeedsRefresh(DateTimeOffset.Now)) {refreshing=true;LoginRefresh(ApplicationId,session.RefreshToken,authCallback);}
            else {LoginAccess(session.AccessToken);refreshTimer!.Start();}
        }
        catch(Exception error) when(IsLoadError(error)) {LoadFailed();}
        catch {StopRuntime();Status="Windows could not restore saved Discord credentials. Connect again.";Changed?.Invoke();}
    }
    public void Connect()
    {
        dispatcher.VerifyAccess();if(disposed||Connecting||Ready) return;
        try {StartRuntime();openOAuthSuccessPage=true;Authorize(ApplicationId,authCallback);}
        catch(Exception error) when(IsLoadError(error)) {LoadFailed();}
    }
    public async Task PublishAsync(AppliedPresence presence)
    {
        dispatcher.VerifyAccess();if(!Ready) throw new InvalidOperationException("Connect Discord before applying.");
        if(pending!=null) throw new InvalidOperationException("Wait for the current presence update.");
        pending=new(TaskCreationOptions.RunContinuationsAsynchronously);var task=pending.Task;var id=++operationId;
        var p=presence.Configuration;var b=p.Buttons;
        try {UpdatePresence(p.Details,p.State,p.LargeImage,p.LargeImageText,p.SmallImage,p.SmallImageText,b.Count>0?b[0].Label:"",b.Count>0?b[0].Url:"",b.Count>1?b[1].Label:"",b.Count>1?b[1].Url:"",presence.Start?.ToUnixTimeSeconds()??0,presence.End?.ToUnixTimeSeconds()??0,presenceCallback,new IntPtr(id));}
        catch {FailPending("Discord could not publish this presence.");}
        try {await task.WaitAsync(TimeSpan.FromSeconds(30));}
        catch(TimeoutException) {FailPending("Discord presence update timed out.");if(initialized) ClearPresence();throw new InvalidOperationException("Discord did not confirm the update in time. Presence was cleared; try Apply again.");}
    }
    private void FailPending(string message) {var completion=pending;pending=null;++operationId;completion?.TrySetException(new InvalidOperationException(message));}
    public void DisablePresence()
    {dispatcher.VerifyAccess();FailPending("Presence was disabled.");if(initialized) ClearPresence();}
    private bool TakeOAuthSuccessPageRequest()
    {
        var requested=openOAuthSuccessPage;openOAuthSuccessPage=false;return requested;
    }
    private void StopRuntime(bool clearPresence=true)
    {
        openOAuthSuccessPage=false;callbackTimer.Stop();refreshTimer.Stop();refreshing=false;FailPending("Discord account disconnected.");
        if(initialized) {if(clearPresence) ClearPresence();Shutdown();generation=ConnectionGeneration();initialized=false;}
        Ready=false;Connecting=false;DisplayName="";Username="";AvatarUrl="";
    }
    public void Disconnect()
    {
        dispatcher.VerifyAccess();StopRuntime();session=null;
        try {secrets.Delete("discord-session");Status="Discord disconnected";}
        catch {Status="Discord disconnected, but Windows could not remove saved credentials.";}
        Changed?.Invoke();
    }
    private static bool IsLoadError(Exception error)=>error is DllNotFoundException or BadImageFormatException or EntryPointNotFoundException;
    private void LoadFailed() {StopRuntime();Status="Discord SDK could not load. Check runtime files and architecture.";Changed?.Invoke();}
    public void VerifyRuntime()
    {
        dispatcher.VerifyAccess();if(disposed||initialized) throw new InvalidOperationException();
        if(TakeOAuthSuccessPageRequest()) throw new InvalidOperationException("Restoring a session would open the OAuth page.");
        openOAuthSuccessPage=true;
        if(!TakeOAuthSuccessPageRequest() || TakeOAuthSuccessPageRequest()) throw new InvalidOperationException("OAuth success page was not consumed exactly once.");
        openOAuthSuccessPage=true;StopRuntime();
        if(TakeOAuthSuccessPageRequest()) throw new InvalidOperationException("Cancelled login retained a browser launch request.");
        for(int cycle=0;cycle<5;cycle++)
        {
            StartRuntime();var created=generation;
            if(!Current(created) || !callbackTimer.IsEnabled) throw new InvalidOperationException("Native runtime was not initialized.");
            StopRuntime();
            if(generation<=created || Current(created) || Ready || Connecting || callbackTimer.IsEnabled || refreshTimer.IsEnabled)
                throw new InvalidOperationException("Native shutdown retained connection state or accepted a stale generation.");
            var stopped=generation;StopRuntime();
            if(generation!=stopped) throw new InvalidOperationException("Repeated runtime teardown was not idempotent.");
        }
    }
    public void Dispose()=>Dispose(true);
    public void Dispose(bool clearPresence)
    {
        if(disposed) return;StopRuntime(clearPresence);disposed=true;
        GC.KeepAlive(statusCallback);GC.KeepAlive(authCallback);GC.KeepAlive(userCallback);GC.KeepAlive(presenceCallback);
    }
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate void StatusCallback(int status,IntPtr context);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate void AuthCallback(int success,IntPtr message,IntPtr accessToken,IntPtr refreshToken,long expiresIn);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate void UserCallback(IntPtr displayName,IntPtr username,IntPtr avatarUrl,IntPtr context);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] private delegate void PresenceCallback(int success,IntPtr message,IntPtr context);
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_initialize")] private static extern void Initialize(ulong applicationId);
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_set_status_callback")] private static extern void SetStatusCallback(StatusCallback callback,IntPtr context);
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_authorize")] private static extern void Authorize(ulong applicationId,AuthCallback callback);
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_run_callbacks")] private static extern void RunCallbacks();
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_connection_generation")] private static extern ulong ConnectionGeneration();
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_clear_presence")] private static extern void ClearPresence();
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_shutdown")] private static extern void Shutdown();
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_get_current_user")] private static extern void GetCurrentUser(UserCallback callback,IntPtr context);
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_login_with_access_token")] private static extern void LoginAccess([MarshalAs(UnmanagedType.LPUTF8Str)] string token);
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_login_with_refresh_token")] private static extern void LoginRefresh(ulong id,[MarshalAs(UnmanagedType.LPUTF8Str)] string token,AuthCallback callback);
    [DllImport("lumaunt_discord",CallingConvention=CallingConvention.Cdecl,EntryPoint="discord_bridge_update_presence")] private static extern void UpdatePresence(
        [MarshalAs(UnmanagedType.LPUTF8Str)] string details,[MarshalAs(UnmanagedType.LPUTF8Str)] string state,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string largeImage,[MarshalAs(UnmanagedType.LPUTF8Str)] string largeText,[MarshalAs(UnmanagedType.LPUTF8Str)] string smallImage,[MarshalAs(UnmanagedType.LPUTF8Str)] string smallText,
        [MarshalAs(UnmanagedType.LPUTF8Str)] string button1,[MarshalAs(UnmanagedType.LPUTF8Str)] string url1,[MarshalAs(UnmanagedType.LPUTF8Str)] string button2,[MarshalAs(UnmanagedType.LPUTF8Str)] string url2,long start,long end,PresenceCallback callback,IntPtr context);
}
