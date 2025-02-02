local settings = require("settings-cat")
local colors = require("colors-cat")

-- Equivalent to the --default domain
sbar.default({
    updates = "when_shown",
    icon = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Bold"],
            size = 14.0
        },
        color = colors.white,
        padding_left = settings.paddings,
        padding_right = settings.paddings,
        -- background = {
        --     image = {
        --         corner_radius = settings.items.corner_radius
        --     }
        -- }
    },
    label = {
        font = {
            family = settings.font.text,
            style = settings.font.style_map["Semibold"],
            size = 13.0
        },
        color = colors.white,
        padding_left = settings.paddings,
        padding_right = settings.paddings
    },
    padding_left = settings.paddings,
    padding_right = settings.paddings,
    background = {
        height = 30,
        corner_radius = 9,
        -- border_width = 2,
        -- border_color = colors.bg2,
        -- image = {
        --     corner_radius = settings.items.corner_radius,
        --     border_color = colors.grey,
        --     border_width = 1
        -- }
    },
    popup = {
        background = {
            border_width = 2,
            corner_radius = 9,
            border_color = colors.popup.border_color,
            color = colors.popup.background_color,
            shadow = {
                drawing = true
            }
        },
        blur_radius = 20
    },
    -- scroll_texts = true
})