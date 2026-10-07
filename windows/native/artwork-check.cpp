#define DISCORDPP_IMPLEMENTATION
#include "discordpp.h"
#include "PresenceArtwork.h"
#include <cstdio>

int main() {
    discordpp::Activity empty{};
    setPresenceArtwork(empty, "", "Leftover large label", "", "Leftover small label");
    if (empty.Assets()) return 1;
    discordpp::Activity blank{};
    setPresenceArtwork(blank, nullptr, "label", " \t", "label");
    if (blank.Assets()) return 2;
    discordpp::Activity large{};
    setPresenceArtwork(large, "https://example.com/large.png", "Large label", "", "Stale small label");
    auto assets = large.Assets();
    if (!assets || assets->LargeImage() != "https://example.com/large.png" || assets->LargeText() != "Large label" || assets->SmallImage() || assets->SmallText()) return 3;
    discordpp::Activity small{};
    setPresenceArtwork(small, "", "Stale large label", "https://example.com/small.png", "Small label");
    assets = small.Assets();
    if (!assets || assets->LargeImage() || assets->LargeText() || assets->SmallImage() != "https://example.com/small.png" || assets->SmallText() != "Small label") return 4;
    discordpp::Activity both{};
    setPresenceArtwork(both, "large", "Large label", "small", "Small label");
    assets = both.Assets();
    if (!assets || assets->LargeImage() != "large" || assets->SmallImage() != "small") return 5;
    std::puts("PASS: empty artwork omits assets; hover text follows its selected image; each image works independently.");
    return 0;
}
