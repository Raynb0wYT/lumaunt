using System.Globalization;
using System.IO;
using System.Net.Http;
using System.Diagnostics;
using System.Windows;
using System.Windows.Controls;
using System.Windows.Media;
using System.Windows.Media.Imaging;
using System.Windows.Threading;
using System.Text.Json;
using Lumaunt.Core;
using Lumaunt.Windows.Discord;
using Lumaunt.Windows.Services;
using Forms=System.Windows.Forms;
namespace Lumaunt.Windows;
public partial class MainWindow : Window
{
    private static readonly HttpClient AvatarClient=new() {Timeout=TimeSpan.FromSeconds(10),MaxResponseContentBufferSize=5*1024*1024};
    private readonly HttpClient api=new() {Timeout=TimeSpan.FromSeconds(30),MaxResponseContentBufferSize=1024*1024};
    private readonly DiscordConnection connection;
    private readonly ImageService images;
    private readonly ModerationService moderation;
    private readonly DispatcherTimer clock;
    private readonly List<PresencePreset> presets;
    private readonly Forms.NotifyIcon tray;
    private AppSettings settings;
    private ILoginStartupBackend? loginStartup;
    private bool updatingLoginStartup;
    private AppliedPresence? active;
    private CancellationTokenSource? avatarRequest,applyRequest;
    private CancellationTokenSource imagePreviewRequest=new();
    private string avatarUrl="",largePreview="",smallPreview="";
    private bool loading=true, applying,deleting,dirty=true,quitting,wasReady,restoreAttempted;
    public MainWindow()
    {
        InitializeComponent();
        settings=LocalStore.Load("settings.json",new AppSettings());presets=LocalStore.Load("presets.json",new List<PresencePreset>());
        images=new ImageService(api);moderation=new ModerationService(api);connection=new DiscordConnection(Dispatcher);
        CustomStartTimeInput.Text=DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss",CultureInfo.InvariantCulture);
        CrashReportsInput.IsChecked=settings.ShareCrashReports;CrashReportsInput.IsEnabled=CrashReportingConfig.Dsn.Length>0;CrashReportingStatus.Text=CrashReportingConfig.Dsn.Length==0?"The existing Sentry project client DSN is needed to enable sharing.":"Optional crash reporting · off by default";LaunchInput.IsChecked=settings.LaunchAtLogin;RestoreInput.IsChecked=settings.RestoreLastPresence;HideApplyInput.IsChecked=settings.HideAfterApply;ClearQuitInput.IsChecked=settings.ClearPresenceOnQuit;UploadsOnImages.IsChecked=settings.AllowHostedUploads;UploadsInput.IsChecked=settings.AllowHostedUploads;
        ThemeInput.SelectedIndex=settings.Theme=="System"?2:settings.Theme=="Light"?1:0;RetentionInput.SelectedIndex=settings.RetentionDays==7?0:settings.RetentionDays==90?2:1;
        RetentionOnImages.SelectedIndex=RetentionInput.SelectedIndex;SetTheme();RefreshLists();
        InitializeTrayMenu();
        tray=new Forms.NotifyIcon {Text="Lumaunt",Icon=System.Drawing.Icon.ExtractAssociatedIcon(Environment.ProcessPath!),Visible=true};
        tray.MouseUp+=(_,e)=>{if(e.Button==Forms.MouseButtons.Right) Dispatcher.BeginInvoke(ShowTrayMenu);};
        tray.DoubleClick+=(_,_)=>Dispatcher.BeginInvoke(()=>{Show();WindowState=WindowState.Normal;Activate();});
        connection.Changed+=UpdateConnection;
        Deactivated+=(_,_)=>PreviewHoverPopup.IsOpen=false;
        Closing+=(_,e)=>
        {
            if(!quitting) {e.Cancel=true;PreviewHoverPopup.IsOpen=false;Hide();return;}
            quitting=true;clock!.Stop();applyRequest?.Cancel();avatarRequest?.Cancel();imagePreviewRequest.Cancel();
            Microsoft.Win32.SystemEvents.UserPreferenceChanged-=SystemThemeChanged;connection.Changed-=UpdateConnection;connection.Dispose(settings.ClearPresenceOnQuit);trayMenu.IsOpen=false;tray.Dispose();api.Dispose();
            applyRequest?.Dispose();avatarRequest?.Dispose();imagePreviewRequest.Dispose();
        };
        clock=new DispatcherTimer(TimeSpan.FromSeconds(1),DispatcherPriority.Background,(_,_)=>
        {
            if(active?.ShouldDisable(DateTimeOffset.Now)==true) Disable();
            UpdateTimerPreview();
        },Dispatcher);
        Microsoft.Win32.SystemEvents.UserPreferenceChanged+=SystemThemeChanged;
        loading=false;RestoreEditorDraft();UpdatePreview();UpdateConnection();Navigate("Presence");
        if(LocalStore.RecoveryMessage!=null) ValidationMessage.Text=LocalStore.RecoveryMessage;
        PreviewKeyDown+=async (_,e)=>
        {
            var mods=System.Windows.Input.Keyboard.Modifiers;var ctrl=System.Windows.Input.ModifierKeys.Control;
            if(mods==ctrl && e.Key==System.Windows.Input.Key.Q) {RequestQuit();e.Handled=true;}
            else if(mods==ctrl && e.Key==System.Windows.Input.Key.F) {Navigate("Presets");PresetSearch.Focus();e.Handled=true;}
            else if(mods==ctrl && e.Key==System.Windows.Input.Key.N) {NewPresetClicked(this,new());e.Handled=true;}
            else if((mods==ctrl||mods==(ctrl|System.Windows.Input.ModifierKeys.Shift)) && e.Key==System.Windows.Input.Key.Enter) {e.Handled=true;if(mods==ctrl) await ApplyAsync();else Disable();}
            else if(mods==ctrl && e.Key>=System.Windows.Input.Key.D1 && e.Key<=System.Windows.Input.Key.D5) {Navigate(new[]{"Presence","Images","Buttons","Presets","Settings"}[(int)e.Key-(int)System.Windows.Input.Key.D1]);e.Handled=true;}
        };
        SourceInitialized+=(_,_)=>UpdateTitleBar();
        Loaded+=async (_,_)=>{connection.RestoreSession();await RefreshLoginStartupAsync();};
        Activated+=async (_,_)=>{if(IsLoaded) await RefreshLoginStartupAsync();};
    }
    internal void VerifyThemes()
    {
        ThemeInput.SelectedIndex=1;
        if(((SolidColorBrush)System.Windows.Application.Current.Resources["PrimaryBrush"]).Color!=Color.FromRgb(0x19,0x20,0x31)) throw new InvalidOperationException("Light theme was not applied.");
        ThemeInput.SelectedIndex=0;
        if(((SolidColorBrush)System.Windows.Application.Current.Resources["PrimaryBrush"]).Color!=Color.FromRgb(0xF4,0xF5,0xFA)) throw new InvalidOperationException("Dark theme was not applied.");
    }
    public void RequestQuit() {quitting=true;Close();}
    private void SettingsAccountClicked(object sender,RoutedEventArgs e)
    {if(connection.Ready) DisconnectClicked(sender,e);else ConnectClicked(sender,e);}
    private void ConnectClicked(object sender,RoutedEventArgs e)=>connection.Connect();
    private void DisconnectClicked(object sender,RoutedEventArgs e) {Disable();restoreAttempted=true;connection.Disconnect();}
    private void UpdateConnection()
    {
        ConnectionStatus.Text=connection.Status;ConnectionBadge.Text=connection.Status;SettingsDisconnect.IsEnabled=connection.Available&&!connection.Connecting;SettingsDisconnect.Content=connection.Ready?"Disconnect":"Connect Discord";
        ConnectButton.IsEnabled=connection.Available&&!connection.Connecting&&!connection.Ready;
        ConnectButton.Visibility=connection.Ready?Visibility.Collapsed:Visibility.Visible;
        DisconnectButton.Visibility=connection.Connecting?Visibility.Visible:Visibility.Collapsed;ConnectionStatus.Visibility=connection.Ready?Visibility.Collapsed:Visibility.Visible;
        AccountCard.Visibility=connection.Ready?Visibility.Visible:Visibility.Collapsed;
        AccountName.Text=!connection.Ready?"Not connected":string.IsNullOrWhiteSpace(connection.DisplayName)?(string.IsNullOrWhiteSpace(connection.Username)?"Discord connected":connection.Username):connection.DisplayName;
        AccountUsername.Text=string.IsNullOrWhiteSpace(connection.Username)?"":"@"+connection.Username;
        var nextAvatar=connection.Ready?connection.AvatarUrl:"";
        if(avatarUrl!=nextAvatar)
        {
            avatarUrl=nextAvatar;avatarRequest?.Cancel();avatarRequest?.Dispose();avatarRequest=null;
            AccountAvatar.Source=null;AvatarFallback.Visibility=Visibility.Visible;
            if(nextAvatar.Length>0) {avatarRequest=new();_=LoadAvatarAsync(nextAvatar,avatarRequest.Token);}
        }
        if(!connection.Ready) applyRequest?.Cancel();
        var becameReady=connection.Ready&&!wasReady;wasReady=connection.Ready;UpdateActions();
        if(becameReady) _=RestoreOnReadyAsync();
    }
    private async Task LoadAvatarAsync(string url, CancellationToken cancellation)
    {
        // Only fetch the SDK-provided Discord CDN image; no token, disk cache or backend request.
        if (!Uri.TryCreate(url, UriKind.Absolute, out var uri) || uri.Scheme != Uri.UriSchemeHttps ||
            (uri.Host != "cdn.discordapp.com" && uri.Host != "media.discordapp.net")) return;
        try
        {
            var bytes = await AvatarClient.GetByteArrayAsync(uri, cancellation);
            if (cancellation.IsCancellationRequested || !connection.Ready || avatarUrl != url) return;
            using var stream = new MemoryStream(bytes);
            var bitmap = new BitmapImage();
            bitmap.BeginInit(); bitmap.CacheOption = BitmapCacheOption.OnLoad;
            bitmap.DecodePixelWidth = 80; bitmap.StreamSource = stream; bitmap.EndInit(); bitmap.Freeze();
            AccountAvatar.Source = bitmap;
            AvatarFallback.Visibility = Visibility.Collapsed;
            if(trayMenu.IsOpen) RefreshTrayMenu();
        }
        catch (Exception error) when (error is HttpRequestException or OperationCanceledException or NotSupportedException or FileFormatException or ArgumentException)
        {
            // A missing/unavailable avatar never affects the authenticated Discord connection.
        }
    }

    private async Task RestoreOnReadyAsync()
    {
        try
        {
            if(active is { } existing)
            {
                if(existing.End<=DateTimeOffset.Now) {Disable();return;}
                await connection.PublishAsync(existing);return;
            }
            if(restoreAttempted) return;restoreAttempted=true;
            if(!settings.RestoreLastPresence) return;
            var saved=LocalStore.Load<AppliedPresence?>("last-presence.json",null);
            if(saved==null || !saved.CanRestore(DateTimeOffset.Now)) return;
            await ApplyAsync(saved.Configuration.DisableWhenTimerEnds?saved.End:null,saved.Configuration,hideAfterApply:false);
        }
        catch {ValidationMessage.Text="Last presence could not be restored. Review it and Apply again.";}
    }
    private bool trimmingEditorText;
    private void EditorChanged(object sender,RoutedEventArgs e)
    {
        if(loading || !IsInitialized || trimmingEditorText) return;
        if(sender is TextBox box)
        {
            var limit=box==Button1Label || box==Button2Label?32:
                box==DetailsInput || box==StateInput || box==LargeTextInput || box==SmallTextInput?128:0;
            if(limit>0)
            {
                var trimmed=PresenceText.TrimToLimit(box.Text,limit);
                if(trimmed!=box.Text)
                {
                    var caret=Math.Min(box.CaretIndex,trimmed.Length);trimmingEditorText=true;
                    try {box.Text=trimmed;box.CaretIndex=caret;} finally {trimmingEditorText=false;}
                }
            }
        }
        dirty=true;UpdatePreview();SaveEditorDraft();
    }
    private PresenceConfiguration ReadConfiguration(bool forPublishing=true)
    {
        var countdown=CountdownMode.IsChecked==true;DateTimeOffset? start=null;TimeSpan duration=TimeSpan.FromMinutes(CountdownEditorMinutes());
        if(countdown)
        {
            if(!int.TryParse(DurationInput.Text,NumberStyles.Integer,CultureInfo.CurrentCulture,out var minutes)||minutes<(forPublishing?1:0)||minutes>1439) throw new ArgumentException("Choose a countdown from 1 minute to 23 hours 59 minutes.");
            duration=TimeSpan.FromMinutes(minutes);
        }
        else if(CustomStartInput.IsChecked==true)
        {
            if(!DateTime.TryParse(CustomStartTimeInput.Text,CultureInfo.CurrentCulture,DateTimeStyles.AllowWhiteSpaces,out var parsed)||TimeZoneInfo.Local.IsInvalidTime(DateTime.SpecifyKind(parsed,DateTimeKind.Unspecified))) throw new ArgumentException("Enter a valid local start time.");
            start=new DateTimeOffset(DateTime.SpecifyKind(parsed,DateTimeKind.Local));
        }
        var buttons=new List<PresenceButton>();
        if(buttonSlots>=1) buttons.Add(new(Button1Label.Text.Trim(),Button1Url.Text.Trim()));
        if(buttonSlots>=2) buttons.Add(new(Button2Label.Text.Trim(),Button2Url.Text.Trim()));
        return new() {Details=DetailsInput.Text,State=StateInput.Text,LargeImage=LargeImageInput.Text.Trim(),SmallImage=SmallImageInput.Text.Trim(),LargeImageText=LargeTextInput.Text,SmallImageText=SmallTextInput.Text,TimerMode=countdown?TimerMode.Countdown:TimerMode.Elapsed,CustomStartTime=start,CountdownDuration=duration,DisableWhenTimerEnds=countdown&&AutoDisableInput.IsChecked==true,Buttons=buttons};
    }
    private void UpdatePreview()
    {
        if(loading) return;
        PreviewDetails.Text=DetailsInput.Text;PreviewState.Text=StateInput.Text;
        PreviewDetails.Visibility=string.IsNullOrWhiteSpace(DetailsInput.Text)?Visibility.Collapsed:Visibility.Visible;
        PreviewState.Visibility=string.IsNullOrWhiteSpace(StateInput.Text)?Visibility.Collapsed:Visibility.Visible;
        var countdown=CountdownMode.IsChecked==true;
        ElapsedOptions.Visibility=countdown?Visibility.Collapsed:Visibility.Visible;CountdownOptions.Visibility=countdown?Visibility.Visible:Visibility.Collapsed;
        CustomStartOptions.Visibility=CustomStartInput.IsChecked==true?Visibility.Visible:Visibility.Collapsed;
        UpdateCountdownControls();TimerHelp.Visibility=countdown?Visibility.Collapsed:Visibility.Visible;
        TimerHelp.Text=countdown?"Discord will show time remaining. Applying starts the countdown.":CustomStartInput.IsChecked==true?"Discord will measure elapsed time from your chosen start time.":"Discord will show how long the presence has been active. Applying starts the timer from now.";
        System.Windows.Automation.AutomationProperties.SetHelpText(PreviewLargeHitRegion,LargeTextInput.Text.Trim());
        System.Windows.Automation.AutomationProperties.SetHelpText(PreviewSmallBadge,SmallTextInput.Text.Trim());
        UpdatePreviewHover();
        PreviewButtons.Children.Clear();
        foreach(var pair in new[]{(Button1Label.Text,Button1Url.Text),(Button2Label.Text,Button2Url.Text)})
        {
            if(string.IsNullOrWhiteSpace(pair.Item1)) continue;
            var button=new Button {Content=pair.Item1,Padding=new Thickness(12,8,12,8),IsEnabled=PresenceValidation.IsWebUrl(pair.Item2),ToolTip=pair.Item2};
            button.Click+=(_,_)=>OpenLink(pair.Item2);PreviewButtons.Children.Add(button);
        }
        if(largePreview!=LargeImageInput.Text || smallPreview!=SmallImageInput.Text)
        {
            largePreview=LargeImageInput.Text;smallPreview=SmallImageInput.Text;imagePreviewRequest.Cancel();imagePreviewRequest.Dispose();imagePreviewRequest=new();
            PreviewLargeImage.Source=null;PreviewEmptyImage.Visibility=Visibility.Visible;PreviewSmallImage.Source=null;PreviewSmallBadge.Visibility=Visibility.Collapsed;
            _=LoadPreviewImagesAsync(largePreview,smallPreview,imagePreviewRequest.Token);
        }
        UpdatePresentation();UpdateTimerPreview();UpdateActions();
    }
    private async Task LoadPreviewImagesAsync(string large,string small,CancellationToken cancellation)
    {
        async Task<BitmapImage?> Load(string value)
        {
            byte[] bytes;
            if(File.Exists(value)) bytes=await File.ReadAllBytesAsync(value,cancellation);
            else if(PresenceValidation.IsWebUrl(value)) bytes=await AvatarClient.GetByteArrayAsync(value,cancellation);
            else return null;
            if(bytes.Length>5*1024*1024) return null;
            var decoded=await Task.Run(()=>ImageService.DecodeWebP(bytes),cancellation);
            using var stream=new MemoryStream(decoded);var image=new BitmapImage();image.BeginInit();image.CacheOption=BitmapCacheOption.OnLoad;image.DecodePixelWidth=160;image.StreamSource=stream;image.EndInit();image.Freeze();return image;
        }
        try {var image=await Load(large);if(!cancellation.IsCancellationRequested&&image!=null) {PreviewLargeImage.Source=image;PreviewEmptyImage.Visibility=Visibility.Collapsed;}} catch { }
        try {var image=await Load(small);if(!cancellation.IsCancellationRequested&&image!=null) {PreviewSmallImage.Source=image;PreviewSmallBadge.Visibility=Visibility.Visible;}} catch { }
        if(!cancellation.IsCancellationRequested) {UpdateImageCards();UpdatePreviewHover();}
    }
    private void UpdateTimerPreview()
    {
        if(active!=null)
        {
            var delta=active.End is { } end?end-DateTimeOffset.Now:DateTimeOffset.Now-(active.Start??DateTimeOffset.Now);
            if(delta<TimeSpan.Zero) delta=TimeSpan.Zero;
            PreviewTimer.Text=$"{(int)delta.TotalHours:00}:{delta.Minutes:00}:{delta.Seconds:00} "+(active.End!=null?"remaining":"elapsed");return;
        }
        PreviewTimer.Text=CountdownMode.IsChecked==true?CountdownPreviewText():"Elapsed time · starts when applied";
    }
    private void UpdateActions()
    {
        ApplyButton.IsEnabled=connection.Ready&&!applying&&!deleting;ApplyButton.Content=applying?"Applying…":active!=null&&!dirty?"✓ Applied":"Apply Presence";
        DisableButton.Visibility=active!=null||applying?Visibility.Visible:Visibility.Collapsed;
        PresenceStatus.Text=applying?"Checking and applying…":active!=null&&connection.Ready?"● Presence active":active!=null?"Presence paused · Discord disconnected":"Presence inactive";
        ApplyHint.Text=connection.Ready?(dirty?"Edits are applied only when you choose Apply.":"Your presence is up to date."):"Connect Discord to apply";
        tray.Text=active!=null&&connection.Ready?"Lumaunt · Presence active":"Lumaunt";
        if(trayMenu.IsOpen) RefreshTrayMenu();
    }
    private async void ApplyClicked(object sender,RoutedEventArgs e)=>await ApplyAsync();
    private async Task ApplyAsync(DateTimeOffset? restoredEnd=null,PresenceConfiguration? restoredConfiguration=null,bool hideAfterApply=true)
    {
        if(applying) return;
        if(deleting) {ValidationMessage.Text="Wait for hosted-image deletion to finish.";return;}
        var epoch=connection.Generation;
        try
        {
            if(!connection.Ready) throw new InvalidOperationException("Connect Discord before applying.");
            var snapshot=restoredConfiguration??ReadConfiguration();PresenceValidation.Validate(snapshot,DateTimeOffset.Now);
            applying=true;ValidationMessage.Text="";applyRequest?.Dispose();applyRequest=new();var token=applyRequest.Token;UpdateActions();
            await moderation.CheckAsync(snapshot,token);
            var large=await images.ResolveAsync(snapshot.LargeImage,settings,token);var small=await images.ResolveAsync(snapshot.SmallImage,settings,token);
            token.ThrowIfCancellationRequested();
            if(!connection.Ready||connection.Generation!=epoch) throw new OperationCanceledException();
            if(restoredEnd<=DateTimeOffset.Now) throw new OperationCanceledException();
            var applied=(snapshot with {LargeImage=large,SmallImage=small}).ApplyTimer(DateTimeOffset.Now,restoredEnd);
            await connection.PublishAsync(applied);
            token.ThrowIfCancellationRequested();if(connection.Generation!=epoch) throw new OperationCanceledException();
            active=applied;dirty=!ConfigurationMatchesEditor(snapshot);
            try {LocalStore.Save("last-presence.json",applied);} catch {ValidationMessage.Text="Presence applied, but the restore copy could not be saved.";}
            if(hideAfterApply&&settings.HideAfterApply) {PreviewHoverPopup.IsOpen=false;Hide();}
        }
        catch(OperationCanceledException) { }
        catch(Exception error) {ValidationMessage.Text=FriendlyError(error);}
        finally {applying=false;if(!quitting) {RefreshLists();UpdateActions();UpdateTimerPreview();}}
    }
    private static string FriendlyError(Exception error)=>error is ArgumentException or InvalidOperationException or HttpRequestException or InvalidDataException?error.Message:error is JsonException?"An invalid response was received. Try again later.":"Lumaunt could not complete this action. Check access to your local files and try again.";
    private void DisableClicked(object sender,RoutedEventArgs e)=>Disable();
    private void Disable()
    {
        applyRequest?.Cancel();connection.DisablePresence();active=null;restoreAttempted=true;dirty=true;
        try {LocalStore.Save<AppliedPresence?>("last-presence.json",null);} catch {ValidationMessage.Text="Presence disabled, but the saved restore copy could not be cleared.";}
        UpdateActions();UpdateTimerPreview();
    }
    private void NavigateClicked(object sender,RoutedEventArgs e)=>Navigate((string)((FrameworkElement)sender).Tag);
    private void Navigate(string page)
    {
        PreviewHoverPopup.IsOpen=false;
        foreach(var (name,panel) in new (string,FrameworkElement)[]{("Presence",PresencePage),("Images",ImagesPage),("Buttons",ButtonsPage),("Presets",PresetsPage),("Settings",SettingsPage)}) panel.Visibility=name==page?Visibility.Visible:Visibility.Collapsed;
        foreach(var button in new[]{NavPresence,NavImages,NavButtons,NavPresets,NavSettings})
        {button.SetResourceReference(Button.BackgroundProperty,(string)button.Tag==page?"SelectionBrush":"SidebarBrush");button.Foreground=(string)button.Tag==page?(Brush)Application.Current.Resources["BrandGradient"]:(Brush)Application.Current.Resources["PrimaryBrush"];}
        currentPage=page;PresenceFooter.Visibility=Visible(page=="Presence");PageTitle.Text=page;ValidationMessage.Text="";ContentScroll.ScrollToTop();SetResponsiveLayout(ContentHost.ActualWidth);UpdateStorageSummary();
    }
    private static void OpenLink(string url)
    {if(PresenceValidation.IsWebUrl(url)) try {Process.Start(new ProcessStartInfo(new Uri(url.Trim(),UriKind.Absolute).AbsoluteUri) {UseShellExecute=true});} catch { } }
    private TextBox ImageInput(string slot)=>slot=="Small"?SmallImageInput:LargeImageInput;
    private async void ChooseImageClicked(object sender,RoutedEventArgs e)
    {
        var dialog=new Microsoft.Win32.OpenFileDialog {Filter="Images|*.png;*.jpg;*.jpeg;*.webp"};
        if(dialog.ShowDialog(this)==true) try {var slot=(string)((Button)sender).Tag;var path=await Task.Run(()=>ImageService.Import(dialog.FileName));if(!quitting) {ImageInput(slot).Text=path;ImageInput(slot).Visibility=Visibility.Collapsed;}} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);}
    }
    private async void PasteImageClicked(object sender,RoutedEventArgs e)
    {try {var slot=(string)((Button)sender).Tag;var path=await ImageService.PasteAsync();if(!quitting) {ImageInput(slot).Text=path;ImageInput(slot).Visibility=Visibility.Collapsed;}} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);} }
    private void RemoveImageClicked(object sender,RoutedEventArgs e) {var box=ImageInput((string)((Button)sender).Tag);box.Clear();box.Visibility=Visibility.Collapsed;}
    private void ImageDragOver(object sender,DragEventArgs e) {e.Effects=e.Data.GetDataPresent(DataFormats.FileDrop)?DragDropEffects.Copy:DragDropEffects.None;e.Handled=true;}
    private async void ImageDropped(object sender,DragEventArgs e)
    {
        if(e.Data.GetData(DataFormats.FileDrop) is string[] {Length:>0} files)
            try {var slot=(string)((StackPanel)sender).Tag;var path=await Task.Run(()=>ImageService.Import(files[0]));if(!quitting) {ImageInput(slot).Text=path;ImageInput(slot).Visibility=Visibility.Collapsed;}} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);}
        e.Handled=true;
    }
    private void SwapButtonsClicked(object sender,RoutedEventArgs e)
    { (Button1Label.Text,Button2Label.Text)=(Button2Label.Text,Button1Label.Text);(Button1Url.Text,Button2Url.Text)=(Button2Url.Text,Button1Url.Text); }
    private void RefreshLists()
    {
        var selected=PresetsList.SelectedItem as PresencePreset;var query=PresetSearch.Text.Trim();var visible=presets.Where(p=>p.Name.Contains(query,StringComparison.OrdinalIgnoreCase)||p.Configuration.Details.Contains(query,StringComparison.OrdinalIgnoreCase)||p.Configuration.State.Contains(query,StringComparison.OrdinalIgnoreCase)).ToList();
        PresetsList.ItemsSource=visible;PresetsList.SelectedItem=visible.FirstOrDefault(p=>p.Id==selected?.Id);PresetEmpty.Visibility=Visible(visible.Count==0);PresetEmpty.Text=presets.Count==0?"No presets yet. Save your current configuration to get started.":"No presets match your search.";
        UpdateStorageSummary();
    }
    private void SavePresets() {LocalStore.Save("presets.json",presets);RefreshLists();}
    private PresencePreset SelectedPreset()=>PresetsList.SelectedItem as PresencePreset ?? throw new ArgumentException("Select a preset first.");
    private void SavePresetClicked(object sender,RoutedEventArgs e)
    {
        try
        {
            var name=PresetName.Text.Trim();if(name.Length==0) throw new ArgumentException("Give your preset a name.");
            var p=ReadConfiguration(forPublishing:false);
            presets.Add(new(Guid.NewGuid(),name,p));SavePresets();PresetEditor.Visibility=Visibility.Collapsed;ValidationMessage.Text="Preset saved.";
        } catch(Exception error) {ValidationMessage.Text=FriendlyError(error);}
    }
    private void LoadPresetClicked(object sender,RoutedEventArgs e) {try {LoadConfiguration(SelectedPreset().Configuration);Navigate("Presence");} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);} }
    private async void ApplyPresetClicked(object sender,RoutedEventArgs e) {try {LoadConfiguration(SelectedPreset().Configuration);await ApplyAsync();} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);} }
    private void RenamePresetClicked(object sender,RoutedEventArgs e)
    {try {var p=SelectedPreset();var name=PresetName.Text.Trim();if(name.Length==0) throw new ArgumentException("Enter the new preset name above.");presets[presets.IndexOf(p)]=p with {Name=name};SavePresets();PresetEditor.Visibility=Visibility.Collapsed;} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);} }
    private void DeletePresetClicked(object sender,RoutedEventArgs e)
    {try {var selected=SelectedPreset();if(MessageBox.Show(this,"Delete this saved preset?","Delete preset",MessageBoxButton.YesNo,MessageBoxImage.Question)!=MessageBoxResult.Yes) return;presets.Remove(selected);SavePresets();} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);} }
    private void LoadConfiguration(PresenceConfiguration p)
    {
        loading=true;buttonSlots=p.Buttons.Count;
        try
        {
            DetailsInput.Text=p.Details;StateInput.Text=p.State;LargeImageInput.Text=p.LargeImage;SmallImageInput.Text=p.SmallImage;LargeTextInput.Text=p.LargeImageText;SmallTextInput.Text=p.SmallImageText;
            ElapsedMode.IsChecked=p.TimerMode==TimerMode.Elapsed;CountdownMode.IsChecked=p.TimerMode==TimerMode.Countdown;CustomStartInput.IsChecked=p.CustomStartTime!=null;
            CustomStartTimeInput.Text=(p.CustomStartTime?.LocalDateTime??DateTime.Now).ToString("yyyy-MM-dd HH:mm:ss",CultureInfo.InvariantCulture);
            DurationInput.Text=p.CountdownDuration.TotalMinutes.ToString(CultureInfo.CurrentCulture);AutoDisableInput.IsChecked=p.DisableWhenTimerEnds;
            Button1Label.Text=p.Buttons.Count>0?p.Buttons[0].Label:"";Button1Url.Text=p.Buttons.Count>0?p.Buttons[0].Url:"";Button2Label.Text=p.Buttons.Count>1?p.Buttons[1].Label:"";Button2Url.Text=p.Buttons.Count>1?p.Buttons[1].Url:"";
        } finally {loading=false;dirty=true;UpdatePreview();SaveEditorDraft();}
    }
    private async void SettingsChanged(object sender,RoutedEventArgs e)
    {
        if(loading) return;
        loading=true;
        if(sender==UploadsOnImages) UploadsInput.IsChecked=UploadsOnImages.IsChecked;
        if(sender==RetentionOnImages) RetentionInput.SelectedIndex=RetentionOnImages.SelectedIndex;UploadsOnImages.IsChecked=UploadsInput.IsChecked;RetentionOnImages.SelectedIndex=RetentionInput.SelectedIndex;loading=false;
        settings=new() {ShareCrashReports=CrashReportsInput.IsChecked==true,ClearPresenceOnQuit=ClearQuitInput.IsChecked==true,LaunchAtLogin=LaunchInput.IsChecked==true,RestoreLastPresence=RestoreInput.IsChecked==true,HideAfterApply=HideApplyInput.IsChecked==true,CloseToTray=true,AllowHostedUploads=UploadsInput.IsChecked==true,RetentionDays=RetentionInput.SelectedIndex==0?7:RetentionInput.SelectedIndex==2?90:30,Theme=ThemeInput.SelectedIndex==2?"System":ThemeInput.SelectedIndex==1?"Light":"Dark"};
        SetTheme();try {CrashReporting.Configure(settings.ShareCrashReports);if(sender==LaunchInput) await SetLaunchAtLoginAsync();LocalStore.Save("settings.json",settings);} catch(Exception error) {ValidationMessage.Text=FriendlyError(error);}
    }
    private void SetTheme()
    {
        var light=settings.Theme=="Light" || (settings.Theme=="System" && (int?)Microsoft.Win32.Registry.GetValue(@"HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize","AppsUseLightTheme",1)!=0);
        foreach(var (key,dark,pale) in new[]{("ErrorBrush","#FFC29C","#A03B06"),("PrimaryBrush","#F4F5FA","#192031"),("BackgroundBrush","#1F2530","#EFF2F8"),("SurfaceBrush","#242A35","#FFFFFF"),("BorderBrush","#343A4C","#CAD1DF"),("MutedBrush","#AFB5C7","#525E74"),("SidebarBrush","#1E273B","#E3EAF6"),("InputBrush","#1F1F1F","#F5F7FB"),("PreviewBrush","#2B303B","#E9EDF5"),("AccountBrush","#252E43","#F5F7FB"),("SelectionBrush","#203654","#D6E8FF")})
            System.Windows.Application.Current.Resources[key]=new SolidColorBrush((Color)ColorConverter.ConvertFromString(light?pale:dark));
        foreach(var button in new[]{NavPresence,NavImages,NavButtons,NavPresets,NavSettings})
            if((string)button.Tag!=currentPage) button.SetResourceReference(Button.ForegroundProperty,"PrimaryBrush");
        UpdateTitleBar();
        foreach(var key in new[]{SystemColors.MenuBrushKey,SystemColors.WindowBrushKey,SystemColors.ControlBrushKey}) Application.Current.Resources[key]=Application.Current.Resources["SurfaceBrush"];
        foreach(var key in new[]{SystemColors.MenuTextBrushKey,SystemColors.WindowTextBrushKey,SystemColors.ControlTextBrushKey}) Application.Current.Resources[key]=Application.Current.Resources["PrimaryBrush"];
    }
    private async Task RefreshLoginStartupAsync()
    {
        if(LocalStore.IsolatedForChecks || updatingLoginStartup || quitting) return;
        updatingLoginStartup=true;LaunchInput.IsEnabled=false;
        try
        {
            loginStartup??=LoginStartup.Create();
            var state=await loginStartup.ReadAsync();
            ReflectLoginStartup(state);
        }
        catch(Exception error){ValidationMessage.Text=FriendlyError(error);}
        finally{updatingLoginStartup=false;LaunchInput.IsEnabled=true;}
    }
    private void ReflectLoginStartup(LoginStartupState state)
    {
        var wasLoading=loading;loading=true;
        try{settings=settings with {LaunchAtLogin=LoginStartup.IsEnabled(state)};LaunchInput.IsChecked=settings.LaunchAtLogin;}
        finally{loading=wasLoading;}
        LocalStore.Save("settings.json",settings);
    }
    private async Task SetLaunchAtLoginAsync()
    {
        if(LocalStore.IsolatedForChecks) return;
        updatingLoginStartup=true;LaunchInput.IsEnabled=false;
        var requested=settings.LaunchAtLogin;
        try
        {
            loginStartup??=LoginStartup.Create();
            var state=await LoginStartup.SetAsync(loginStartup,requested);
            ReflectLoginStartup(state);
            if(LoginStartup.Explanation(state,requested) is {} message) ValidationMessage.Text=message;
        }
        catch
        {
            if(loginStartup!=null) ReflectLoginStartup(await loginStartup.ReadAsync());
            throw;
        }
        finally{updatingLoginStartup=false;LaunchInput.IsEnabled=true;}
    }
    private void SystemThemeChanged(object sender,Microsoft.Win32.UserPreferenceChangedEventArgs e)
    {if(settings.Theme=="System"&&!quitting) Dispatcher.BeginInvoke(SetTheme);}
}
