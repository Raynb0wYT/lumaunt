using System.Text.Json;
using Lumaunt.Core;
using Lumaunt.Windows.Services;

namespace Lumaunt.Windows;

// Preserve unfinished input separately from the last successfully published presence.
internal sealed record EditorDraft(string Details, string State, string LargeImage, string SmallImage,
    string LargeText, string SmallText, bool Countdown, bool CustomStart, string StartTime,
    string Duration, bool AutoDisable, int ButtonSlots, string FirstLabel, string FirstUrl,
    string SecondLabel, string SecondUrl);

public partial class MainWindow
{
    private EditorDraft CaptureEditorDraft() => new(DetailsInput.Text,StateInput.Text,
        LargeImageInput.Text,SmallImageInput.Text,LargeTextInput.Text,SmallTextInput.Text,
        CountdownMode.IsChecked==true,CustomStartInput.IsChecked==true,CustomStartTimeInput.Text,
        DurationInput.Text,AutoDisableInput.IsChecked==true,buttonSlots,
        Button1Label.Text,Button1Url.Text,Button2Label.Text,Button2Url.Text);

    private void SaveEditorDraft()
    {
        if(loading||quitting) return;
        try {LocalStore.Save("editor-draft.json",CaptureEditorDraft());}
        catch {ValidationMessage.Text="Your editor changes could not be saved. Check access to Lumaunt's local data folder.";}
    }

    private void RestoreEditorDraft()
    {
        var draft=LocalStore.Load<EditorDraft?>("editor-draft.json",null);
        if(draft==null) return;
        loading=true;
        try
        {
            DetailsInput.Text=draft.Details;StateInput.Text=draft.State;
            LargeImageInput.Text=draft.LargeImage;SmallImageInput.Text=draft.SmallImage;
            LargeTextInput.Text=draft.LargeText;SmallTextInput.Text=draft.SmallText;
            CountdownMode.IsChecked=draft.Countdown;ElapsedMode.IsChecked=!draft.Countdown;
            CustomStartInput.IsChecked=draft.CustomStart;CustomStartTimeInput.Text=draft.StartTime;
            DurationInput.Text=draft.Duration;AutoDisableInput.IsChecked=draft.AutoDisable;
            buttonSlots=Math.Clamp(draft.ButtonSlots,0,2);
            Button1Label.Text=draft.FirstLabel;Button1Url.Text=draft.FirstUrl;
            Button2Label.Text=draft.SecondLabel;Button2Url.Text=draft.SecondUrl;
        }
        finally {loading=false;}
    }

    private bool ConfigurationMatchesEditor(PresenceConfiguration configuration)
    {
        try {return JsonSerializer.Serialize(configuration)==JsonSerializer.Serialize(ReadConfiguration());}
        catch(ArgumentException) {return false;}
    }
}
