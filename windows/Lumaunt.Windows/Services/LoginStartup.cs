using System.ComponentModel;
using System.Runtime.InteropServices;
using Microsoft.Win32;
using Windows.ApplicationModel;
namespace Lumaunt.Windows.Services;

internal enum LoginStartupState { Disabled, Enabled, DisabledByUser, DisabledByPolicy, EnabledByPolicy }
internal interface ILoginStartupBackend
{
    Task<LoginStartupState> ReadAsync();
    Task<LoginStartupState> EnableAsync();
    void Disable();
}
internal static class LoginStartup
{
    internal const string TaskId="LumauntStartup";
    [DllImport("kernel32.dll",CharSet=CharSet.Unicode)]
    private static extern int GetCurrentPackageFullName(ref uint length,IntPtr name);
    internal static bool IsPackaged
    {
        get
        {
            uint length=0;var result=GetCurrentPackageFullName(ref length,IntPtr.Zero);
            return result switch {15700=>false,122=>true,_=>throw new Win32Exception(result)};
        }
    }
    internal static ILoginStartupBackend Create()=>IsPackaged?new PackagedBackend():new RegistryBackend();
    internal static bool IsEnabled(LoginStartupState state)=>state is LoginStartupState.Enabled or LoginStartupState.EnabledByPolicy;
    internal static async Task<LoginStartupState> SetAsync(ILoginStartupBackend backend,bool enabled)
    {
        var current=await backend.ReadAsync();
        if(enabled)
        {
            // Windows owns user/policy blocks. Never override them or fall back to registry startup.
            return current==LoginStartupState.Disabled?await backend.EnableAsync():current;
        }
        if(current==LoginStartupState.Enabled) backend.Disable();
        return await backend.ReadAsync();
    }
    internal static string? Explanation(LoginStartupState state,bool requested)=>state switch
    {
        LoginStartupState.DisabledByUser when requested=>"Windows has disabled launch at login. Enable Lumaunt in Windows Settings → Apps → Startup.",
        LoginStartupState.DisabledByPolicy when requested=>"Launch at login is disabled by your organization's Windows policy.",
        LoginStartupState.EnabledByPolicy when !requested=>"Launch at login is required by your organization's Windows policy.",
        LoginStartupState.Disabled when requested=>"Windows did not enable launch at login.",
        _=>null
    };
    private sealed class PackagedBackend:ILoginStartupBackend
    {
        private StartupTask? task;
        private async Task<StartupTask> GetAsync()=>task??=await StartupTask.GetAsync(TaskId);
        public async Task<LoginStartupState> ReadAsync()=>Convert((await GetAsync()).State);
        public async Task<LoginStartupState> EnableAsync()=>Convert(await (await GetAsync()).RequestEnableAsync());
        public void Disable()=>(task??throw new InvalidOperationException("Startup task has not been loaded.")).Disable();
        private static LoginStartupState Convert(StartupTaskState state)=>state switch
        {
            StartupTaskState.Disabled=>LoginStartupState.Disabled,
            StartupTaskState.Enabled=>LoginStartupState.Enabled,
            StartupTaskState.DisabledByUser=>LoginStartupState.DisabledByUser,
            StartupTaskState.DisabledByPolicy=>LoginStartupState.DisabledByPolicy,
            StartupTaskState.EnabledByPolicy=>LoginStartupState.EnabledByPolicy,
            _=>throw new InvalidOperationException("Unknown Windows startup state.")
        };
    }
    private sealed class RegistryBackend:ILoginStartupBackend
    {
        private const string Key=@"Software\Microsoft\Windows\CurrentVersion\Run";
        private static string Command=>"\""+Environment.ProcessPath+"\" --tray";
        public Task<LoginStartupState> ReadAsync()
        {
            using var key=Registry.CurrentUser.OpenSubKey(Key);
            return Task.FromResult(key?.GetValue("LumauntWindows") as string==Command?LoginStartupState.Enabled:LoginStartupState.Disabled);
        }
        public Task<LoginStartupState> EnableAsync()
        {
            using var key=Registry.CurrentUser.CreateSubKey(Key);key.SetValue("LumauntWindows",Command);
            return Task.FromResult(LoginStartupState.Enabled);
        }
        public void Disable(){using var key=Registry.CurrentUser.OpenSubKey(Key,true);key?.DeleteValue("LumauntWindows",false);}
    }
}
