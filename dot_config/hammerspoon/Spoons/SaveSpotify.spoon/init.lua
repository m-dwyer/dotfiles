--- === SaveSpotify ===
---
--- Adds a hotkey to save the currently playing Spotify track into my Obsidian vault, as defined by OBSIDIAN_VAULT
--- This allows me to process all the tracks I enjoy in my inbox and later download FLACs
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "SaveSpotify"
obj.version = "1.0.0"
obj.author = "Em Dwyer <em@emdwyer.dev>"
obj.homepage = "https://emdwyer.dev/"

--- Configuration for file to save to
--- Change accordingly

obj.spotifyTextFile = os.getenv("HOME") .. "/Documents/vault/Inbox/Spotify Tracks.md"

-- Function to append text to a file
function obj:appendToFile(path, text)
    local file = io.open(path, "a")
    if file then
        file:write(text .. "\n")
        file:close()
    end
end

-- Function to get current Spotify track
function obj:getCurrentSpotifyTrack()
    local artistName = hs.spotify.getCurrentArtist()
    local trackName = hs.spotify.getCurrentTrack()
    local albumName = hs.spotify.getCurrentAlbum()

    if trackName and artistName then
        return artistName .. " - " .. trackName .. " (" .. albumName .. ")"
    else
        return "No track playing"
    end
end

-- Function to handle the hotkey
function obj:saveCurrentTrack()
    local currentTrack = self:getCurrentSpotifyTrack()
    local markdownText = "- [ ] " .. currentTrack
    self:appendToFile(self.spotifyTextFile, markdownText)
    hs.alert.show("Saving track: " .. currentTrack)
end

function obj:likeCurrentTrack()
    local app = hs.application.find("com.spotify.client")
	hs.eventtap.keyStroke({"option", "shift"}, "b", app)
end

return obj
