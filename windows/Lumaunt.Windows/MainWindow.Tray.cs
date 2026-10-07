using System.Windows;
using System.Windows.Controls;
using System.Windows.Controls.Primitives;
using System.Windows.Interop;
using System.Windows.Media;
namespace Lumaunt.Windows;
public partial class MainWindow
{
    private readonly ContextMenu trayMenu=new();
    private readonly TrayPanel trayPanel=new();
    private MenuItem? trayDisable;
    [System.Runtime.InteropServices.DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr window);
    private void InitializeTrayMenu()
    {
        var information=new MenuItem {Header=trayPanel,IsEnabled=false,Style=(Style)Application.Current.Resources["TrayInformationItem"]};
        trayMenu.Items.Add(information);trayMenu.Items.Add(new Separator());
        MenuItem Action(string label,string glyph,RoutedEventHandler action)
        {
            var content=new StackPanel {Orientation=Orientation.Horizontal};
            content.Children.Add(new TextBlock {Text=glyph,FontFamily=new FontFamily("Segoe MDL2 Assets"),FontSize=15,Width=24,VerticalAlignment=VerticalAlignment.Center});
            content.Children.Add(new TextBlock {Text=label});var item=new MenuItem {Header=content};
            System.Windows.Automation.AutomationProperties.SetName(item,label);item.Click+=action;return item;
        }
        trayMenu.Items.Add(Action("Open Lumaunt","\uE737",(_,_)=>{Show();WindowState=WindowState.Normal;Activate();}));
        trayDisable=Action("Disable Presence","\uE71A",DisableClicked);trayMenu.Items.Add(trayDisable);
        trayMenu.Items.Add(new Separator());trayMenu.Items.Add(Action("Quit Lumaunt","\uE7E8",QuitClicked));
        trayMenu.Opened+=(_,_)=>
        {
            // Give the popup foreground ownership so Windows can dismiss it on an outside click,
            // including while the main window is hidden. Do not reopen the main window.
            if(PresentationSource.FromVisual(trayMenu) is HwndSource source) _=SetForegroundWindow(source.Handle);
            trayMenu.Focus();
        };
    }
    private void RefreshTrayMenu()
    {
        var published=active!=null&&connection.Ready;
        trayPanel.Update(AccountName.Text,AccountUsername.Text,AccountAvatar.Source,connection.Status,connection.Ready,published,active?.Configuration.Details??"",active?.Configuration.State??"");
        if(trayDisable!=null) trayDisable.IsEnabled=published;
    }
    private void ShowTrayMenu()
    {
        if(quitting) return;
        RefreshTrayMenu();trayMenu.Placement=PlacementMode.MousePoint;trayMenu.PlacementTarget=this;trayMenu.IsOpen=true;
    }
}
