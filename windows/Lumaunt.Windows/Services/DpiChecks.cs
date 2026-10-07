using System.Runtime.InteropServices;
namespace Lumaunt.Windows.Services;
internal static class DpiChecks
{
    [DllImport("user32.dll")] private static extern IntPtr GetThreadDpiAwarenessContext();
    [DllImport("user32.dll")] [return:MarshalAs(UnmanagedType.Bool)]
    private static extern bool AreDpiAwarenessContextsEqual(IntPtr first,IntPtr second);
    internal static bool Verify()
    {
        if(System.Diagnostics.Process.GetCurrentProcess().SessionId==0) return false;
        if(!AreDpiAwarenessContextsEqual(GetThreadDpiAwarenessContext(),new IntPtr(-4)))
            throw new InvalidOperationException("Lumaunt is not running with PerMonitorV2 DPI awareness.");
        return true;
    }
}
