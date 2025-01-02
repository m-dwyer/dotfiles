--- === Obsidian ===
---
--- Adds a popup menu with Obsidian Advanced URI options for quick access
---

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "Obsidian"
obj.version = "1.0"
obj.author = "Em Dwyer <em@emdwyer.dev>"
obj.homepage = "https://emdwyer.dev/"

-- Define the items for the chooser
local menuItems = {
    {
        text = "📥 Inbox",
        subText = "Add to Inbox",
        url = "obsidian://advanced-uri?vault=vault&commandid=quickadd%253Achoice%253Ac09b214c-6ba9-4865-8e08-44954e634984"
    },
    {
        text = "📔 Journal",
        subText = "Add Journal Entry",
        url = "obsidian://advanced-uri?commandid=quickadd%3Achoice%3Aa8ea42ba-9436-438b-abe6-22f6d6ebe86b"
    },
    {
        text = "📔 Journal - Highlight",
        subText = "Add Journal Entry",
        url = "obsidian://adv-uri?commandid=quickadd%3Achoice%3A18b253ac-4112-42ff-8394-0455b772ff6b"
    },
    {
        text = "✅ Task",
        subText = "Add Task",
        url = "obsidian://advanced-uri?commandid=quickadd%3Achoice%3A67406d0a-2105-4b1f-8100-a4d02ef4869a"
    },
    {
        text = "🌞 Daily",
        subText = "Open Daily Note",
        url = "obsidian://advanced-uri?daily=true"
    }
}

local function onMenuSelect(choice)
    if not choice then
        return -- No choice made, just close the menu
    end

    hs.urlevent.openURL(choice.url)
end

function obj:showMenu()
    local chooser = hs.chooser.new(onMenuSelect)
    chooser
        :placeholderText("Select an action")
        :choices(menuItems)
        :show()
end

return obj
