-- Shared popup dismissal.
--
-- sketchybar documents mouse.exited.global as "when the mouse leaves all parts of
-- the bar", but delivery is unreliable in practice — see FelixKratz/SketchyBar
-- issues #564, #613 ("mouse.exited is not reliable") and #638 ("popup items get
-- stuck"). On this machine it only fires when the pointer reaches the very top of
-- the screen and reveals the auto-hidden macOS menu bar, so popups stayed open
-- when moving along the bar or clicking into another app.
--
-- So rather than rely on that single event, every widget registers a closer here
-- and we dismiss from the signals that ARE reliable, backed by a watchdog.

local M = {}

-- Seconds with the pointer away from the widget/popup before dismissing.
local IDLE_SECONDS = 3
-- Hard cap from the moment the popup opened, whatever the hover state says.
-- mouse.exited is unreliable too, so without this a missed exit event would leave
-- the watchdog convinced the pointer is still inside, and it would never close.
local MAX_SECONDS = 15

local closers = {}

-- name is used so a widget can dismiss the others without dismissing itself.
function M.register(name, closer)
    closers[name] = closer
end

local watchdog = sbar.add("item", {
    drawing = false,
    updates = false,
    update_freq = 1
})

local armed = false
local inside = false
local idle_left = 0
local age_left = 0

local function stop()
    armed = false
    watchdog:set({ updates = false })
end

-- Deliberately does NOT stop the watchdog itself. Each closer disarms only when
-- it actually closed something, so close_all("volume") while the volume popup is
-- open leaves its watchdog running instead of orphaning it.
function M.close_all(except)
    for name, closer in pairs(closers) do
        if name ~= except then
            closer()
        end
    end
end

-- Called when a popup is revealed.
function M.arm()
    armed = true
    inside = true
    idle_left = IDLE_SECONDS
    age_left = MAX_SECONDS
    watchdog:set({ updates = true })
end

function M.disarm()
    stop()
end

-- Widgets report hover transitions on themselves and on their popup rows, so the
-- idle countdown only advances while the pointer is actually away.
function M.hover(is_inside)
    inside = is_inside
    if is_inside then
        idle_left = IDLE_SECONDS
    end
end

watchdog:subscribe("routine", function()
    if not armed then
        stop()
        return
    end

    age_left = age_left - 1
    if not inside then
        idle_left = idle_left - 1
    end

    if age_left <= 0 or idle_left <= 0 then
        stop()
        M.close_all()
    end
end)

-- Clicking into another application dismisses everything. front_app_switched is
-- reliable — items/menus.lua already depends on it.
local observer = sbar.add("item", {
    drawing = false,
    updates = true
})

observer:subscribe("front_app_switched", function()
    M.close_all()
end)

return M
