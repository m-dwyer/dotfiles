local colors = require("colors-cat")
local icons = require("icons-cat")
local settings = require("settings-cat")

local apple = sbar.add("item", {
    icon = {
        font = {
            family = settings.font.text,
            size = 16.0
        },
        string = icons.apple,
        padding_right = 15,
        color = colors.green,
    },
    label = {
        drawing = false
    },
    -- background = {
    --     color = settings.items.colors.background,
    --     border_color = settings.modes.main.color,
    --     border_width = 1
    -- },

    padding_left = 1,
    padding_right = 1,
    click_script = "$CONFIG_DIR/helpers/menus/bin/menus -s 0"
})

apple:subscribe("aerospace_enter_service_mode", function(_)
    sbar.animate("tanh", 10, function()
        apple:set({
            background = {
                border_color = settings.modes.service.color,
                border_width = 3
            },
            icon = {
                highlight = true,
                string = settings.modes.service.icon
            }
        })

    end)
end)

apple:subscribe("aerospace_leave_service_mode", function(_)
    sbar.animate("tanh", 10, function()
        apple:set({
            background = {
                border_color = settings.modes.main.color,
                border_width = 1
            },
            icon = {
                highlight = false,
                string = settings.modes.main.icon
            }
        })
    end)
end)

-- Padding to the right of the main button
sbar.add("item", {
    width = 7
})