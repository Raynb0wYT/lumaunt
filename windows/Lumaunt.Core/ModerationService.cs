using System.Net.Http.Json;
using System.Text.Json;
namespace Lumaunt.Core;
public sealed class ModerationService(HttpClient client)
{
    public async Task CheckAsync(PresenceConfiguration presence,CancellationToken cancellation)
    {
        foreach(var (name,text) in PresenceValidation.Fields(presence))
        {
            if(string.IsNullOrWhiteSpace(text)) continue;
            var decision=ContentFilter.Evaluate(text);
            if(decision.BlockedCategory!=null) throw new ArgumentException($"{name}: {decision.Reason}");
            foreach(var category in decision.ReviewCategories)
            {
                using var response=await client.PostAsJsonAsync("https://api.lumaunt.app/v1/moderate/context",new {text=text.Trim(),suspectedCategory=category},cancellation);
                if(!response.IsSuccessStatusCode) throw new HttpRequestException("The moderation service could not review this presence. Try again later.");
                using var json=JsonDocument.Parse(await response.Content.ReadAsStringAsync(cancellation));
                var r=json.RootElement;
                if(r.ValueKind!=JsonValueKind.Object || !r.TryGetProperty("success",out var success) || success.ValueKind!=JsonValueKind.True ||
                    !r.TryGetProperty("category",out var returnedCategory) || returnedCategory.ValueKind!=JsonValueKind.String || returnedCategory.GetString()!=category ||
                    !r.TryGetProperty("classification",out var classificationValue) || classificationValue.ValueKind!=JsonValueKind.String ||
                    !r.TryGetProperty("confirmed",out var confirmedValue) || (confirmedValue.ValueKind!=JsonValueKind.True && confirmedValue.ValueKind!=JsonValueKind.False))
                    throw new InvalidDataException("Invalid moderation response.");
                var classification=classificationValue.GetString(); var confirmed=confirmedValue.GetBoolean();
                if(classification=="violation" && confirmed) throw new ArgumentException($"{name} could not be applied because it violates the {category} policy.");
                if(classification!="contextual" || confirmed) throw new InvalidDataException("Invalid moderation response.");
            }
        }
    }
}
