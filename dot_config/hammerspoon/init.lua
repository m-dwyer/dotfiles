-- Load ReloadConfiguration Spoon
hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

hs.loadSpoon("SaveTidal")
TidalSaver = hs.loadSpoon("SaveTidal")

-- Bind hotkey to save current Tidal track
-- hs.hotkey.bind({ "cmd", "shift" }, "S", function()
--    hs.alert.show("doing the thing")
--    TidalSaver:saveCurrentTrack()
-- end)

-- Load Obsidian Spoon
hs.loadSpoon("Obsidian")

-- Bind hotkey to show our Obsidian menu
-- hs.hotkey.bind({ "cmd", "shift" }, "M", function()
--    spoon.Obsidian:showMenu()
-- end)

-- Load Cheetah
hs.loadSpoon("Cheetah")
spoon.Cheetah:bindHotkeys({
   {
      file = "System",
      toggle = { { "cmd", "shift" }, "H" }
   }
})

local yabaiPath = "/opt/homebrew/bin/yabai"
local opacity = "0.0"
-- Bind hotkey to hide Mac menubar using Yabai
hs.hotkey.bind({ "cmd", "shift" }, "B", function()
   if opacity == "0.0" then
      opacity = "1.0"
   else
      opacity = "0.0"
   end
   hs.task.new(yabaiPath, function() end, { "-m", "config", "menubar_opacity", opacity }):start()
end)
