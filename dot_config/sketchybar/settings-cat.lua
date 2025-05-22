local colors = require("colors-cat")
local icons = require("icons")

local font = "SF Pro"

return {
    updates = 'when_shown',
    paddings = 3,
    bar = {
        topmost = true,
        height = 39,
        background = colors.bar.bg1,
        shadow = true,
        position = "top",
        sticky = true,
        padding = {
            x = 10,
            y = 10
        },
        corner_radius = 9,
        y_offset = 10,
        margin = 10,
        blur_radius = 20,
        -- notch_width = 0
    },
    defaults = {
        updates = "when_shown",
        icon = {
            font = font .. ":Bold:14.0",
            color = colors.icon.color,
            padding_left = 3,
            padding_right = 3,

        },
        label = {
            font = font .. ":Semibold:13.0",
            color = colors.label.color,
            padding_left = 3,
            padding_right = 3
        },
        padding_left = 3,
        padding_right = 3,
        background = {
            height = 30,
            corner_radius = 9
        },
        popup = {
            background = {
                border_width = 2,
                corner_radius = 9,
                border_color = colors.popup.border,
                color = colors.popup.bg,
                shadow = {
                    drawing = true
                }
            },
            blur_radius = 20,
        }
    },
    space = {
        padding_left = 2,
        padding_right = 2,
        label = {
            padding_right = 20,
            font = font .. ":Regular:16.0",
            background = {
                height = 26,
                drawing = true,
                color = colors.bg2,
                corner_radius = 8
            },
            drawing = false
        }
    },

    items = {
        height = 26,
        gap = 5,
        padding = {
            right = 16,
            left = 12,
            top = 0,
            bottom = 0
        },
        default_color = function(workspace)
            return colors.rainbow[workspace + 1]
        end,
        highlight_color = function(workspace)
            return colors.yellow
        end,
        colors = {
            background = colors.bg1
        },
        corner_radius = 6
    },

    icons = "sketchybar-app-font:Regular:16.0", -- alternatively available: NerdFont

    font = {
        -- text = "SpaceMono Nerd Font",
        -- numbers = "SpaceMono Nerd Font",
        text = "FiraCode Nerd Font Mono",    -- Used for text
        numbers = "FiraCode Nerd Font Mono", -- Used for numbers
        style_map = {
            ["Regular"] = "Regular",
            ["Semibold"] = "Medium",
            ["Bold"] = "SemiBold",
            ["Heavy"] = "Bold",
            ["Black"] = "ExtraBold"
        },
        size = 13.0
    }
}
