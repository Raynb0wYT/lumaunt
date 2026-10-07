#pragma once
#include <string>

// Only selected artwork creates assets; leftover hover text must not create them.
inline bool hasArtworkValue(const char* value) {
    return value && std::string(value).find_first_not_of(" \t\r\n") != std::string::npos;
}
inline void setPresenceArtwork(discordpp::Activity& activity, const char* largeImage,
    const char* largeText, const char* smallImage, const char* smallText) {
    const bool large = hasArtworkValue(largeImage);
    const bool small = hasArtworkValue(smallImage);
    if (!large && !small) return;
    discordpp::ActivityAssets assets{};
    if (large) {
        assets.SetLargeImage(std::string(largeImage));
        if (hasArtworkValue(largeText)) assets.SetLargeText(std::string(largeText));
    }
    if (small) {
        assets.SetSmallImage(std::string(smallImage));
        if (hasArtworkValue(smallText)) assets.SetSmallText(std::string(smallText));
    }
    activity.SetAssets(assets);
}
