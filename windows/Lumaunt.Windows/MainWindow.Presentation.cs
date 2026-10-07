using System.Globalization;
using System.IO;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using Lumaunt.Core;
using Lumaunt.Windows.Services;
namespace Lumaunt.Windows;
public partial class MainWindow
{
    [System.Runtime.InteropServices.DllImport("dwmapi.dll")]
    private static extern int DwmSetWindowAttribute(IntPtr window,int attribute,ref int value,int size);
    private void UpdateTitleBar()
    {
        if(!OperatingSystem.IsWindowsVersionAtLeast(10,0,22000)) return;
        var handle=new System.Windows.Interop.WindowInteropHelper(this).Handle;if(handle==IntPtr.Zero) return;
        var background=((SolidColorBrush)Application.Current.Resources["BackgroundBrush"]).Color;
        var text=((SolidColorBrush)Application.Current.Resources["PrimaryBrush"]).Color;
        int dark=background.R<128?1:0,caption=background.R|(background.G<<8)|(background.B<<16),foreground=text.R|(text.G<<8)|(text.B<<16);
        _=DwmSetWindowAttribute(handle,20,ref dark,sizeof(int));
        _=DwmSetWindowAttribute(handle,35,ref caption,sizeof(int));
        _=DwmSetWindowAttribute(handle,36,ref foreground,sizeof(int));
    }
    private int buttonSlots;
    private string currentPage="Presence";
    private void ContentSizeChanged(object sender,SizeChangedEventArgs e)=>SetResponsiveLayout(e.NewSize.Width);
    private void SetResponsiveLayout(double width)
    {
        var wide=width>=1000;
        EditorColumn.Width=new GridLength(wide?1.15:1,GridUnitType.Star);
        PreviewColumn.Width=wide?new GridLength(1,GridUnitType.Star):new GridLength(0);
        Grid.SetColumn(PreviewPane,wide?1:0);Grid.SetRow(PreviewPane,wide?0:1);
        PreviewPane.Margin=wide?new Thickness(24,0,0,0):new Thickness(0,26,0,0);
    }
    private static Visibility Visible(bool show)=>show?Visibility.Visible:Visibility.Collapsed;
    private void UpdatePresentation()
    {
        foreach(var (box,count,limit) in new[]{(DetailsInput,DetailsInputCount,128),(StateInput,StateInputCount,128),(LargeTextInput,LargeTextInputCount,128),(SmallTextInput,SmallTextInputCount,128),(Button1Label,Button1LabelCount,32),(Button2Label,Button2LabelCount,32)})
            count.Text=$"{new StringInfo(box.Text).LengthInTextElements} / {limit}";
        Button1Card.Visibility=Visible(buttonSlots>=1);Button2Card.Visibility=Visible(buttonSlots>=2);ButtonsEmpty.Visibility=Visible(buttonSlots==0);
        AddButtonControl.Visibility=Visible(buttonSlots==1);ButtonLimit.Text=buttonSlots==2?"✓ Maximum of 2 buttons reached.":"";
        Button1Up.IsEnabled=false;Button1Down.IsEnabled=buttonSlots==2;Button2Up.IsEnabled=buttonSlots==2;Button2Down.IsEnabled=false;
        foreach(var (box,hint) in new[]{(Button1Url,Button1Validity),(Button2Url,Button2Validity)})
        {var valid=PresenceValidation.IsWebUrl(box.Text);hint.Text=box.Text.Length==0?"":valid?"✓ Valid URL":"Enter a valid URL";hint.Foreground=valid?new SolidColorBrush(Color.FromRgb(0x32,0xCE,0x68)):(Brush)Application.Current.Resources["ErrorBrush"];}
        UpdateImageCards();
    }
    private void UpdateImageCards()
    {
        foreach(var (input,empty,selected,file,label,thumb,source) in new[]{(LargeImageInput,LargeEmpty,LargeSelected,LargeFileName,LargeSourceLabel,LargeThumbnail,PreviewLargeImage),(SmallImageInput,SmallEmpty,SmallSelected,SmallFileName,SmallSourceLabel,SmallThumbnail,PreviewSmallImage)})
        {
            var value=input.Text.Trim();empty.Visibility=Visible(value.Length==0);selected.Visibility=Visible(value.Length>0);
            var local=File.Exists(value);file.Text=local?Path.GetFileName(value):value;
            label.Text=local?"✓ Stored locally by Lumaunt":PresenceValidation.IsWebUrl(value)?"Public image URL":"Discord artwork asset";
            thumb.Source=source.Source;
        }
    }
    private void UseImageUrlClicked(object sender,RoutedEventArgs e)
    {var box=ImageInput((string)((FrameworkElement)sender).Tag);box.Visibility=Visibility.Visible;box.Focus();box.SelectAll();}
    private void AddButtonClicked(object sender,RoutedEventArgs e)
    {if(buttonSlots>=2) return;buttonSlots++;UpdatePresentation();SaveEditorDraft();(buttonSlots==1?Button1Label:Button2Label).Focus();}
    private void RemoveButtonClicked(object sender,RoutedEventArgs e)
    {
        var slot=int.Parse((string)((FrameworkElement)sender).Tag);
        loading=true;
        if(slot==1) {Button1Label.Text=Button2Label.Text;Button1Url.Text=Button2Url.Text;}
        Button2Label.Clear();Button2Url.Clear();if(buttonSlots==1) {Button1Label.Clear();Button1Url.Clear();}
        buttonSlots=Math.Max(0,buttonSlots-1);loading=false;dirty=true;UpdatePreview();SaveEditorDraft();
    }
    private async void PresetArtworkLoaded(object sender,RoutedEventArgs e)
    {
        var target=(Image)sender;var value=target.Tag as string;if(string.IsNullOrWhiteSpace(value)) return;
        try
        {
            byte[] bytes;if(File.Exists(value)) bytes=await File.ReadAllBytesAsync(value);
            else if(PresenceValidation.IsWebUrl(value)) bytes=await AvatarClient.GetByteArrayAsync(value);else return;
            if(bytes.Length>5*1024*1024) return;
            var decoded=await Task.Run(()=>ImageService.DecodeWebP(bytes));using var stream=new MemoryStream(decoded);
            var image=new System.Windows.Media.Imaging.BitmapImage();image.BeginInit();image.CacheOption=System.Windows.Media.Imaging.BitmapCacheOption.OnLoad;image.DecodePixelWidth=120;image.StreamSource=stream;image.EndInit();image.Freeze();
            if(!quitting && target.Tag as string==value) target.Source=image;
        } catch { }
    }
    private void NewPresetClicked(object sender,RoutedEventArgs e)
    {Navigate("Presets");PresetEditor.Visibility=Visibility.Visible;SavePresetControl.Visibility=Visibility.Visible;RenamePresetControl.Visibility=Visibility.Collapsed;PresetName.Clear();PresetName.Focus();}
    private void CancelPresetEditClicked(object sender,RoutedEventArgs e)=>PresetEditor.Visibility=Visibility.Collapsed;
    private void PresetSearchChanged(object sender,TextChangedEventArgs e) {if(!loading) RefreshLists();}
    private void PresetCardLoadClicked(object sender,RoutedEventArgs e)
    {PresetsList.SelectedItem=((FrameworkElement)sender).Tag;LoadPresetClicked(sender,e);}
    private void PresetCardApplyClicked(object sender,RoutedEventArgs e)
    {PresetsList.SelectedItem=((FrameworkElement)sender).Tag;ApplyPresetClicked(sender,e);}
    private void PresetMenuClicked(object sender,RoutedEventArgs e)
    {
        var button=(Button)sender;PresetsList.SelectedItem=button.Tag;
        var menu=new ContextMenu();var load=new MenuItem {Header="Load preset"};load.Click+=LoadPresetClicked;menu.Items.Add(load);menu.Items.Add(new Separator());
        var rename=new MenuItem {Header="Rename…"};rename.Click+=(_,_)=>{PresetEditor.Visibility=Visibility.Visible;SavePresetControl.Visibility=Visibility.Collapsed;RenamePresetControl.Visibility=Visibility.Visible;PresetName.Text=SelectedPreset().Name;PresetName.Focus();PresetName.SelectAll();};menu.Items.Add(rename);
        var duplicate=new MenuItem {Header="Duplicate"};duplicate.Click+=DuplicatePresetClicked;menu.Items.Add(duplicate);menu.Items.Add(new Separator());
        var delete=new MenuItem {Header="Delete preset…"};delete.Click+=DeletePresetClicked;menu.Items.Add(delete);menu.PlacementTarget=button;menu.IsOpen=true;
    }
    private void DuplicatePresetClicked(object sender,RoutedEventArgs e)
    {
        try {var preset=SelectedPreset();presets.Insert(presets.IndexOf(preset)+1,preset with {Id=Guid.NewGuid(),Name=preset.Name+" Copy"});SavePresets();}
        catch(Exception error) {ValidationMessage.Text=FriendlyError(error);}
    }
    private void AccountMenuClicked(object sender,RoutedEventArgs e)
    {var menu=new ContextMenu();var item=new MenuItem {Header="Disconnect account"};item.Click+=DisconnectClicked;menu.Items.Add(item);menu.PlacementTarget=(Button)sender;menu.IsOpen=true;}
    private void QuitClicked(object sender,RoutedEventArgs e)=>RequestQuit();
    private void WebsiteClicked(object sender,RoutedEventArgs e)=>OpenLink("https://lumaunt.app");
    private void ClearUploadCacheClicked(object sender,RoutedEventArgs e)
    {
        if(applying||deleting) {ValidationMessage.Text="Wait for the current action to finish.";return;}
        if(MessageBox.Show(this,"Remove locally stored Lumaunt images and the upload cache? Hosted images are not deleted, and their deletion ownership records are kept. Presets using local artwork may need a replacement image.","Clear local image cache",MessageBoxButton.YesNo,MessageBoxImage.Question)!=MessageBoxResult.Yes) return;
        try {images.ClearLocalImageCache();RefreshLists();ValidationMessage.Text="Local image cache cleared. Hosted images and deletion ownership records kept.";} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);}
    }
    private async void DeleteAllHostedClicked(object sender,RoutedEventArgs e)
    {
        if(applying||deleting) {ValidationMessage.Text="Wait for the current action to finish.";return;}
        var records=images.Hosted.ToList();if(records.Count==0) {ValidationMessage.Text="No managed hosted images to delete.";return;}
        if(MessageBox.Show(this,$"Permanently delete {records.Count} hosted image(s)? Their public URLs will stop working. Your local files are kept.","Delete hosted images",MessageBoxButton.YesNo,MessageBoxImage.Warning)!=MessageBoxResult.Yes) return;
        int removed=0;
        try
        {
            deleting=true;UpdateActions();
            foreach(var image in records)
            {await images.DeleteAsync(image,CancellationToken.None);removed++;if(active?.Configuration.LargeImage==image.Url||active?.Configuration.SmallImage==image.Url) Disable();}
            ValidationMessage.Text="Hosted images deleted. Local files kept.";
        }
        catch(Exception error) {ValidationMessage.Text=$"Deleted {removed} of {records.Count} images. "+FriendlyError(error);}
        finally {deleting=false;RefreshLists();UpdateActions();}
    }
    private void UpdateStorageSummary()
    {
        var managed=images.Hosted;var earliest=managed.Count==0?"":$" Earliest expiry: {DateTimeOffset.FromUnixTimeMilliseconds(managed.Min(i=>i.ExpiresAt)).LocalDateTime:g}";
        HostedSummaryInput.Text=HostedSummaryOnImages.Text=$"{managed.Count} managed upload(s)."+earliest;
        CacheSummary.Text=$"{managed.Count(i=>i.Hash.Length>0 && i.ExpiresAt>DateTimeOffset.Now.ToUnixTimeMilliseconds())} cached upload(s)";
        var directory=Path.Combine(LocalStore.Root,"images");var files=Directory.Exists(directory)?new DirectoryInfo(directory).GetFiles():Array.Empty<FileInfo>();
        StorageSummary.Text=$"{files.Length} locally stored image(s) · {files.Sum(f=>f.Length)/1024:N0} KB";
    }
    internal void VerifyPresentation()
    {
        trayPanel.Verify();RefreshTrayMenu();
        foreach(var box in new[]{DetailsInput,StateInput,LargeTextInput,SmallTextInput,Button1Label,Button2Label})
        {
            var limit=box==Button1Label || box==Button2Label?32:128;
            var expected=string.Concat(Enumerable.Repeat("👨‍👩‍👧‍👦",limit));
            box.Text=expected+"🇺🇸";
            if(box.Text!=expected) throw new InvalidOperationException("Editor split or prematurely truncated emoji text.");
            box.Clear();
        }
        LoadConfiguration(new PresenceConfiguration {TimerMode=TimerMode.Countdown,CountdownDuration=TimeSpan.Zero,Buttons=new[]{new PresenceButton("","")}});
        PresetName.Text="Unfinished preset";SavePresetClicked(this,new());
        var draftPreset=LocalStore.Load("presets.json",new List<PresencePreset>()).Single(p=>p.Name=="Unfinished preset");
        if(draftPreset.Configuration.Buttons.Count!=1 || draftPreset.Configuration.CountdownDuration!=TimeSpan.Zero)
            throw new InvalidOperationException("Saving an unfinished preset lost empty buttons or duration.");
        try {PresenceValidation.Validate(draftPreset.Configuration,DateTimeOffset.Now);throw new InvalidOperationException("Unfinished preset was publishable.");}
        catch(ArgumentException) { }
        LoadConfiguration(draftPreset.Configuration);
        if(buttonSlots!=1 || Button1Label.Text!="" || DurationInput.Text!="0") throw new InvalidOperationException("Loading unfinished preset changed its configuration.");
        LoadConfiguration(new PresenceConfiguration());

        SetResponsiveLayout(1100);if(Grid.GetColumn(PreviewPane)!=1||Grid.GetRow(PreviewPane)!=0) throw new InvalidOperationException("Wide presence layout failed.");
        SetResponsiveLayout(650);if(Grid.GetColumn(PreviewPane)!=0||Grid.GetRow(PreviewPane)!=1) throw new InvalidOperationException("Compact presence layout failed.");
        AddButtonClicked(this,new());AddButtonClicked(this,new());AddButtonClicked(this,new());if(buttonSlots!=2) throw new InvalidOperationException("Button limit failed.");
        Button1Label.Text="First";Button1Url.Text="https://example.com/first";Button2Label.Text="Second";Button2Url.Text="https://example.com/second";
        SwapButtonsClicked(this,new());if(ReadConfiguration().Buttons[0].Label!="Second") throw new InvalidOperationException("Button reorder failed.");
        RemoveButtonClicked(new Button {Tag="1"},new());if(ReadConfiguration().Buttons.Single().Label!="First") throw new InvalidOperationException("Button removal failed.");
        RemoveButtonClicked(new Button {Tag="1"},new());if(buttonSlots!=0||ButtonsEmpty.Visibility!=Visibility.Visible) throw new InvalidOperationException("Button empty state failed.");
        foreach(var page in new[]{"Presence","Images","Buttons","Presets","Settings"})
        {Navigate(page);ContentHost.Measure(new Size(1100,double.PositiveInfinity));ContentHost.Arrange(new Rect(0,0,1100,1000));ContentHost.UpdateLayout();}
        UploadsOnImages.IsChecked=true;RetentionOnImages.SelectedIndex=2;
        if(!settings.AllowHostedUploads||settings.RetentionDays!=90||UploadsInput.IsChecked!=true||RetentionInput.SelectedIndex!=2) throw new InvalidOperationException("Image privacy settings are not synchronized.");
        UploadsInput.IsChecked=false;RetentionInput.SelectedIndex=0;
        if(UploadsOnImages.IsChecked!=false||RetentionOnImages.SelectedIndex!=0) throw new InvalidOperationException("Settings privacy changes did not reach Images.");
        var original=new PresencePreset(Guid.NewGuid(),"Duplicate fixture",new PresenceConfiguration {Details="Original details",Buttons=new[]{new PresenceButton("Example","https://example.com")}});
        presets.Clear();presets.Add(original);SavePresets();PresetsList.SelectedItem=original;DuplicatePresetClicked(this,new());
        if(presets.Count!=2||presets[0]!=original||presets[1].Id==original.Id||presets[1].Name!="Duplicate fixture Copy"||presets[1].Configuration!=original.Configuration) throw new InvalidOperationException("Duplicating a preset changed its configuration or original record.");
        var saved=LocalStore.Load("presets.json",new List<PresencePreset>());if(saved.Count!=2||saved[1].Id!=presets[1].Id) throw new InvalidOperationException("Duplicate preset was not persisted.");
        // Repeated workflows retain unfinished draft input, not only valid published data.
        for(int cycle=0;cycle<3;cycle++)
        {
            DetailsInput.Text=$"Draft {cycle} ✦";StateInput.Text="Unapplied edits";
            CountdownMode.IsChecked=true;DurationInput.Text="unfinished";
            Button1Label.Text="Draft link";Button1Url.Text="https://";buttonSlots=1;
            SaveEditorDraft();var before=CaptureEditorDraft();
            // Simulate fresh controls during startup without persisting them over the saved draft.
            loading=true;
            try {DetailsInput.Text="Temporary replacement";DurationInput.Text="60";}
            finally {loading=false;}
            RestoreEditorDraft();
            if(CaptureEditorDraft()!=before) throw new InvalidOperationException("Unfinished editor draft was lost during restoration.");
            if(ConfigurationMatchesEditor(new PresenceConfiguration())) throw new InvalidOperationException("An invalid timer draft was treated as applied.");
            foreach(var page in new[]{"Images","Buttons","Presets","Settings","Presence"}) Navigate(page);
            foreach(var width in new[]{540d,650d,999d,1000d,1400d}) SetResponsiveLayout(width);
        }
        DurationInput.Text="60";ElapsedMode.IsChecked=true;
        DetailsInput.Text="";StateInput.Text="";Button1Label.Clear();Button1Url.Clear();buttonSlots=0;
        if(SettingsDisconnect.Content as string!="Connect Discord" || !SettingsDisconnect.IsEnabled) throw new InvalidOperationException("Settings does not offer Connect while disconnected.");
        if(new AppSettings().Theme!="System" || new AppSettings().ClearPresenceOnQuit) throw new InvalidOperationException("New-user defaults differ from macOS.");
        UpdatePreview();Navigate("Presence");
    }
}
