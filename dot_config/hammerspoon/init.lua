-- Load ReloadConfiguration Spoon
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- Load SpotifySaver Spoon
hs.loadSpoon("SaveSpotify")

-- Initialize and configure SaveSpotify
SpotifySaver = hs.loadSpoon("SaveSpotify")

-- Bind hotkey to both save and like the current Spotify track
hs.hotkey.bind({"cmd", "shift"}, "S", function()
   SpotifySaver:saveCurrentTrack()
   SpotifySaver:likeCurrentTrack()
end)

-- Load Obsidian Spoon
Obsidian = hs.loadSpoon("Obsidian")

-- Bind hotkey to show our Obsidian menu
hs.hotkey.bind({"cmd", "shift"}, "M", function()
   Obsidian:showMenu()
end)