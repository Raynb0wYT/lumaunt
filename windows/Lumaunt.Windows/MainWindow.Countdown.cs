using System.Globalization;
using System.Windows;

namespace Lumaunt.Windows;
public partial class MainWindow
{
    private int CountdownEditorMinutes()
    {
        return int.TryParse(DurationInput.Text,NumberStyles.Integer,CultureInfo.CurrentCulture,out var value)
            ? Math.Clamp(value,0,1439) : 0;
    }
    private void UpdateCountdownControls()
    {
        var total=CountdownEditorMinutes();var hours=total/60;var minutes=total%60;
        CountdownHoursLabel.Text=$"{hours} hr";CountdownMinutesLabel.Text=$"{minutes} min";
        CountdownHoursUp.IsEnabled=hours<23;CountdownHoursDown.IsEnabled=hours>0;
        CountdownMinutesUp.IsEnabled=minutes<59;CountdownMinutesDown.IsEnabled=minutes>0;
        var valid=int.TryParse(DurationInput.Text,NumberStyles.Integer,CultureInfo.CurrentCulture,out var raw)&&raw>=1&&raw<=1439;
        CountdownError.Text=total==0?"Countdown must be at least 1 minute.":"Choose a countdown up to 23 hours 59 minutes.";
        CountdownError.Visibility=CountdownMode.IsChecked==true&&!valid?Visibility.Visible:Visibility.Collapsed;
    }
    private void CountdownStepClicked(object sender,RoutedEventArgs e)
    {
        var total=CountdownEditorMinutes();var hours=total/60;var minutes=total%60;
        switch((string)((FrameworkElement)sender).Tag)
        {
            case "HoursUp": hours=Math.Min(23,hours+1);break;
            case "HoursDown": hours=Math.Max(0,hours-1);break;
            case "MinutesUp": minutes=Math.Min(59,minutes+1);break;
            case "MinutesDown": minutes=Math.Max(0,minutes-1);break;
        }
        DurationInput.Text=(hours*60+minutes).ToString(CultureInfo.CurrentCulture);
    }
    private string CountdownPreviewText()
    {
        var total=CountdownEditorMinutes();
        return $"{total/60}:{total%60:00}:00 remaining";
    }
    internal void VerifyCountdownSteppers()
    {
        CountdownMode.IsChecked=true;DurationInput.Text="60";
        var step=new System.Windows.Controls.Button();
        void Click(string tag) {step.Tag=tag;CountdownStepClicked(step,new());}
        Click("HoursUp");Click("MinutesUp");
        if(ReadConfiguration().CountdownDuration!=TimeSpan.FromMinutes(121)) throw new InvalidOperationException("Countdown steppers changed the wrong unit.");
        ElapsedMode.IsChecked=true;
        if(ReadConfiguration().CountdownDuration!=TimeSpan.FromMinutes(121)) throw new InvalidOperationException("Switching timer modes lost the selected countdown duration.");
        CountdownMode.IsChecked=true;
        Click("HoursDown");Click("MinutesDown");
        if(ReadConfiguration().CountdownDuration!=TimeSpan.FromHours(1)) throw new InvalidOperationException("Countdown decrement failed.");
        DurationInput.Text="1439";Click("HoursUp");Click("MinutesUp");
        if(DurationInput.Text!="1439"||CountdownHoursUp.IsEnabled||CountdownMinutesUp.IsEnabled) throw new InvalidOperationException("Countdown upper bound failed.");
        DurationInput.Text="0";Click("HoursDown");Click("MinutesDown");
        if(DurationInput.Text!="0"||CountdownHoursDown.IsEnabled||CountdownMinutesDown.IsEnabled||CountdownError.Visibility!=Visibility.Visible) throw new InvalidOperationException("Countdown zero state failed.");
        try {ReadConfiguration();throw new InvalidOperationException("Zero countdown was accepted.");} catch(ArgumentException) { }
        Click("MinutesUp");AutoDisableInput.IsChecked=true;
        if(ReadConfiguration().CountdownDuration!=TimeSpan.FromMinutes(1)||!ReadConfiguration().DisableWhenTimerEnds) throw new InvalidOperationException("Minimum countdown or auto-disable failed.");
        SaveEditorDraft();loading=true;
        try {DurationInput.Text="60";} finally {loading=false;}
        RestoreEditorDraft();UpdatePreview();
        if(DurationInput.Text!="1"||CountdownMinutesLabel.Text!="1 min") throw new InvalidOperationException("Countdown edits did not persist.");
        DurationInput.Text="60";AutoDisableInput.IsChecked=false;ElapsedMode.IsChecked=true;
    }
}
