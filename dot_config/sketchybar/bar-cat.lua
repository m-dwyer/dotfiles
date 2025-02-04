local settings = require("settings-cat")

-- Equivalent to the --bar domain
sbar.bar({
    height = settings.bar.height,
    color = settings.bar.background,
    shadow = settings.bar.shadow,
    position = settings.bar.position,
    sticky = settings.bar.sticky,
    padding_right = settings.bar.padding.x,
    padding_left = settings.bar.padding.x,
    corner_radius = settings.bar.corner_radius,
    y_offset = settings.bar.y_offset,
    margin = settings.bar.margin,
    blur_radius = settings.bar.blur_radius,
    -- notch_width = settings.b
})
