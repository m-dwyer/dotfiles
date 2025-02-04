local settings = require("settings-cat")
local colors = require("colors-cat")

-- Equivalent to the --default domain
sbar.default({
    updates = settings.defaults.updates,
    icon = {
        font = settings.defaults.icon.font,
        color = settings.defaults.icon.color,
        padding_left = settings.defaults.padding_left,
        padding_right = settings.defaults.padding_right,
    },
    label = {
        font = settings.defaults.label.font,
        color = settings.defaults.label.color,
        padding_left = settings.defaults.label.padding_left,
        padding_right = settings.defaults.label.padding_right
    },
    padding_left = settings.defaults.padding_left,
    padding_right = settings.defaults.padding_right,
    background = {
        height = settings.defaults.background.height,
        corner_radius = settings.defaults.background.corner_radius
    },
    popup = {
        background = {
            border_width = settings.defaults.popup.background.border_width,
            corner_radius = settings.defaults.popup.background.corner_radius,
            border_color = settings.defaults.popup.background.border_color,
            color = settings.defaults.popup.background.shadow,
        },
        blur_radius = settings.defaults.popup.blur_radius
    },
    scroll_texts = true
})