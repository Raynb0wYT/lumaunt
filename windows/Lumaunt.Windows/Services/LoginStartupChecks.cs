namespace Lumaunt.Windows.Services;
internal static class LoginStartupChecks
{
    internal static async Task RunPackagedAsync()
    {
        Require(LoginStartup.IsPackaged,"Check must run from an installed MSIX");
        using var registry=Microsoft.Win32.Registry.CurrentUser.OpenSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run");
        var before=registry?.GetValue("LumauntWindows");
        var backend=LoginStartup.Create();var original=await backend.ReadAsync();
        Require(original is LoginStartupState.Disabled or LoginStartupState.Enabled,"Windows startup blocked; test cannot change it");
        try
        {
            Require(await LoginStartup.SetAsync(backend,true)==LoginStartupState.Enabled,"Real task enable");
            Require(await backend.ReadAsync()==LoginStartupState.Enabled,"Real enabled readback");
            Require(await LoginStartup.SetAsync(backend,false)==LoginStartupState.Disabled,"Real task disable");
            Require(await backend.ReadAsync()==LoginStartupState.Disabled,"Real disabled readback");
            Require(Equals(before,registry?.GetValue("LumauntWindows")),"Packaged startup must not write registry startup");
        }
        finally{await LoginStartup.SetAsync(backend,LoginStartup.IsEnabled(original));}
        Require(await backend.ReadAsync()==original,"Restore original task state");
    }
    internal static async Task RunAsync()
    {
        var backend=new FakeBackend(LoginStartupState.Disabled);
        Require(await LoginStartup.SetAsync(backend,true)==LoginStartupState.Enabled && backend.Enables==1,"Enable disabled task");
        await LoginStartup.SetAsync(backend,true);
        Require(backend.Enables==1,"Already-enabled task must not be requested twice");
        Require(await LoginStartup.SetAsync(backend,false)==LoginStartupState.Disabled && backend.Disables==1,"Disable enabled task");
        await LoginStartup.SetAsync(backend,false);
        Require(backend.Disables==1,"Already-disabled task must not be disabled twice");
        foreach(var blocked in new[]{LoginStartupState.DisabledByUser,LoginStartupState.DisabledByPolicy,LoginStartupState.EnabledByPolicy})
        {
            backend=new FakeBackend(blocked);
            Require(await LoginStartup.SetAsync(backend,true)==blocked,"Respect Windows enable override");
            Require(await LoginStartup.SetAsync(backend,false)==blocked,"Respect Windows disable override");
            Require(backend.Enables==0 && backend.Disables==0,"Do not mutate user/policy override");
            Require(LoginStartup.IsEnabled(blocked)==(blocked==LoginStartupState.EnabledByPolicy),"Reflect actual Windows state");
        }
        backend=new FakeBackend(LoginStartupState.Disabled){EnableResult=LoginStartupState.DisabledByUser};
        var result=await LoginStartup.SetAsync(backend,true);
        Require(!LoginStartup.IsEnabled(result) && LoginStartup.Explanation(result,true)!=null,"Surface Windows refusal after enable request");
        backend=new FakeBackend(LoginStartupState.Disabled){FailEnable=true};
        try{await LoginStartup.SetAsync(backend,true);throw new Exception("Startup failure was swallowed");}
        catch(InvalidOperationException){Require(await backend.ReadAsync()==LoginStartupState.Disabled,"Failed request leaves disabled state");}
    }
    private static void Require(bool condition,string message){if(!condition)throw new Exception("Launch-at-login check: "+message);}
    private sealed class FakeBackend(LoginStartupState initial):ILoginStartupBackend
    {
        private LoginStartupState state=initial;
        internal int Enables,Disables;
        internal LoginStartupState EnableResult=LoginStartupState.Enabled;
        internal bool FailEnable;
        public Task<LoginStartupState> ReadAsync()=>Task.FromResult(state);
        public Task<LoginStartupState> EnableAsync(){Enables++;if(FailEnable)throw new InvalidOperationException("Simulated Windows failure");state=EnableResult;return Task.FromResult(state);}
        public void Disable(){Disables++;state=LoginStartupState.Disabled;}
    }
}
