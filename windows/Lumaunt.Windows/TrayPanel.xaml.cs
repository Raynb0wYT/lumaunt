using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
namespace Lumaunt.Windows;
public partial class TrayPanel : UserControl
{
    public TrayPanel()=>InitializeComponent();
    internal void Update(string name,string username,ImageSource? avatar,string status,bool connected,bool active,string details,string state)
    {
        ProfileRow.Visibility=connected?Visibility.Visible:Visibility.Collapsed;
        ConnectionState.Visibility=connected?Visibility.Collapsed:Visibility.Visible;ConnectionState.Text=status;
        DisplayName.Text=name;Username.Text=username;Avatar.Source=connected?avatar:null;
        AvatarPlaceholder.Visibility=avatar==null?Visibility.Visible:Visibility.Collapsed;
        PresenceState.Text=active?"Active":"No active presence";
        PresenceDot.SetResourceReference(ShapeFillProperty(),active?"TrayActiveBrush":"MutedBrush");
        Details.Text=active?details:"";State.Text=active?state:"";
        Details.Visibility=Details.Text.Length>0?Visibility.Visible:Visibility.Collapsed;
        State.Visibility=State.Text.Length>0?Visibility.Visible:Visibility.Collapsed;
    }
    private static DependencyProperty ShapeFillProperty()=>System.Windows.Shapes.Shape.FillProperty;
    internal void Verify()
    {
        Update("Test name","@test",null,"Connected",true,true,"Published details","Published state");
        if(ProfileRow.Visibility!=Visibility.Visible||Details.Text!="Published details"||PresenceState.Text!="Active") throw new InvalidOperationException("Tray connected snapshot failed.");
        Update("","",null,"Discord disconnected",false,false,"Stale details","Stale state");
        if(ProfileRow.Visibility!=Visibility.Collapsed||Avatar.Source!=null||Details.Text.Length!=0||State.Text.Length!=0||PresenceState.Text!="No active presence") throw new InvalidOperationException("Tray disconnect retained stale profile or presence.");
        Measure(new Size(270,double.PositiveInfinity));Arrange(new Rect(0,0,270,DesiredSize.Height));UpdateLayout();
    }
}
