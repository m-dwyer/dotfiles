local settings = require("settings-cat")

local colors = require("colors-cat")

-- Equivalent to the --bar domain
sbar.bar({
    topmost = "topmost",
    height = settings.bar.height,
    color = colors.bar.color,
    padding_right = settings.bar.padding.x,
    padding_left = settings.bar.padding.x,
    notch_width = 200,
    sticky = settings.bar.sticky,
    position = settings.bar.position,
    shadow = settings.bar.shadow
})
