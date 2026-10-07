using System.Windows;
using System.Windows.Input;
using System.Windows.Threading;

namespace Lumaunt.Windows;

public partial class MainWindow
{
    private void PreviewArtworkHoverChanged(object sender, MouseEventArgs e)
    {
        // Re-evaluate after WPF updates IsMouseOver when crossing the small badge.
        Dispatcher.BeginInvoke(DispatcherPriority.Input, new Action(UpdatePreviewHover));
    }

    private void UpdatePreviewHover()
    {
        if (PreviewHoverPopup == null) return;
        var small = PreviewSmallBadge.IsVisible && PreviewSmallBadge.IsMouseOver;
        var large = PreviewLargeHitRegion.IsMouseOver && PreviewLargeImage.Source != null;
        var text = small ? SmallTextInput.Text.Trim() : large ? LargeTextInput.Text.Trim() : "";
        PreviewHoverText.Text = text;
        PreviewHoverPopup.PlacementTarget = small ? PreviewSmallBadge : PreviewLargeHitRegion;
        PreviewHoverPopup.IsOpen = IsVisible && PresencePage.IsVisible && text.Length > 0;
    }
}
