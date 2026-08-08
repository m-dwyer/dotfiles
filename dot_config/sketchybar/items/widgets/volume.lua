local colors = require("colors-cat")
local icons = require("icons")
local settings = require("settings-cat")
local popups = require("helpers.popups")

local popup_width = 250

local volume_percent = sbar.add("item", "widgets.volume1", {
    position = "right",
    icon = {
        drawing = false
    },
    label = {
        string = "??%",
        padding_left = -1,
        font = {
            family = settings.font.numbers
        }
    }
})

local volume_icon = sbar.add("item", "widgets.volume2", {
    position = "right",
    padding_right = -1,
    -- icon = {
    --     -- string = icons.volume._100,
    --     width = 0,
    --     align = "left",
    --     color = colors.grey,
    --     font = {
    --         style = settings.font.style_map["Regular"],
    --         size = 14.0
    --     }
    -- },
    label = {
        width = 25,
        align = "left",
        font = {
            style = settings.font.style_map["Regular"],
            size = 14.0
        }
    }
})

local volume_bracket = sbar.add("bracket", "widgets.volume.bracket", {volume_icon.name, volume_percent.name}, {
    background = {
        color = colors.bg1,
        border_color = colors.bg2,
        border_width = 1
    },
    popup = {
        align = "center"
    }
})

sbar.add("item", "widgets.volume.padding", {
    position = "right",
    width = settings.group_paddings
})

local volume_slider = sbar.add("slider", popup_width, {
    position = "popup." .. volume_bracket.name,
    slider = {
        highlight_color = colors.blue,
        background = {
            height = 6,
            corner_radius = 3,
            color = colors.bg2
        },
        knob = {
            string = "􀀁",
            drawing = true
        }
    },
    background = {
        color = colors.bg1,
        height = 2,
        y_offset = -20
    },
    click_script = 'osascript -e "set volume output volume $PERCENTAGE"'
})

volume_percent:subscribe("volume_change", function(env)
    local volume = tonumber(env.INFO)
    local lead = volume < 10 and "0" or ""

    -- The percentage and the slider derive purely from env.INFO, which sketchybar
    -- hands us directly. They used to live inside the SwitchAudioSource callback
    -- below, which gated them behind an ~80ms subprocess on every scroll tick.
    volume_percent:set({ label = lead .. volume .. "%" })
    volume_slider:set({ slider = { percentage = volume } })

    -- Only the icon depends on which device is active, so only it waits.
    sbar.exec("SwitchAudioSource -t output -c", function(result)
        Current_output_device = result:sub(1, -2)

        local icon = icons.volume._0
        if Current_output_device == "BT" then
            icon = "􀺹"
        elseif Current_output_device == "AirPods2" then
            icon = "􀟥"
        elseif Current_output_device == "WH-1000XM6" then
            icon = "􀑈"
        elseif Current_output_device == "AirPods4" then
            icon = "􁄡"
        elseif Current_output_device == "Ear (2)" then
            icon = "􀪷"
        elseif Current_output_device == "iD4" then
            icon = "􀝎"
        else
            if volume > 60 then
                icon = icons.volume._100
            elseif volume > 30 then
                icon = icons.volume._66
            elseif volume > 10 then
                icon = icons.volume._33
            elseif volume > 0 then
                icon = icons.volume._10
            end
        end

        volume_icon:set({ label = icon })
    end)
end)

-- Last known output devices, so a reopen does not have to wait ~80ms for
-- SwitchAudioSource. Written only by the fetch below, so there is one source of
-- truth. nil until the first successful fetch.
local cached_current, cached_available = nil, nil

-- Whether the user currently wants the popup open. Needed because the fetch is
-- async: without it, dismissing the popup mid-query would let the callback pop it
-- back open, or repaint items into a popup that has already been torn down.
local want_open = false

local function volume_collapse_details()
    want_open = false

    local drawing = volume_bracket:query().popup.drawing == "on"
    if not drawing then
        return
    end
    popups.disarm()
    volume_bracket:set({
        popup = {
            drawing = false
        }
    })
    sbar.remove('/volume.device\\.*/')
end

-- Populates the popup with the output devices. Does NOT reveal it — callers
-- decide when to draw, so the popup is never shown before it has content. (It
-- used to open at slider height, sit there for the ~160ms the two
-- SwitchAudioSource calls took, then visibly grow as each row was appended.)
local function volume_render_devices(current, available)
    -- Defensive: collapse already clears these, but a rapid re-open could race.
    sbar.remove('/volume.device\\.*/')

    local counter = 0
    for device in string.gmatch(available, '[^\r\n]+') do
        local row = sbar.add("item", "volume.device." .. counter, {
            position = "popup." .. volume_bracket.name,
            width = popup_width,
            align = "center",
            label = {
                string = device,
                color = (device == current) and colors.white or colors.grey
            },
            click_script = 'SwitchAudioSource -s "' .. device ..
                '" && sketchybar --set /volume.device\\.*/ label.color=' .. colors.grey ..
                ' --set $NAME label.color=' .. colors.white
        })
        row:subscribe("mouse.entered", function() popups.hover(true) end)
        row:subscribe("mouse.exited", function() popups.hover(false) end)
        counter = counter + 1
    end
end

local function volume_draw()
    volume_bracket:set({
        popup = {
            drawing = true
        }
    })
    popups.arm()
end

-- Queries the current device and the device list concurrently and joins them.
-- Each call costs ~80ms; nested they cost ~160ms.
local function volume_fetch(done)
    local pending, current, available = 2, nil, nil
    local function join()
        pending = pending - 1
        if pending > 0 then
            return
        end
        done(current, available)
    end

    sbar.exec("SwitchAudioSource -t output -c", function(result)
        current = result:sub(1, -2)
        join()
    end)
    sbar.exec("SwitchAudioSource -a -t output", function(result)
        available = result
        join()
    end)
end

local function volume_toggle_details(env)
    if env.BUTTON == "right" then
        sbar.exec("open /System/Library/PreferencePanes/Sound.prefpane")
        return
    end

    if volume_bracket:query().popup.drawing == "on" then
        volume_collapse_details()
        return
    end

    want_open = true

    -- Open instantly from the last known device list. Only the very first open
    -- after a reload has to wait for the fetch.
    local shown_from_cache = cached_available ~= nil
    if shown_from_cache then
        volume_render_devices(cached_current, cached_available)
        volume_draw()
    end

    -- Refresh in the background regardless, so the cache cannot go stale: a
    -- device plugged in since the last open shows up here.
    volume_fetch(function(current, available)
        local changed = current ~= cached_current or available ~= cached_available
        cached_current, cached_available = current, available

        if not want_open then
            -- Dismissed while the query was in flight.
            return
        end

        if not shown_from_cache then
            volume_render_devices(current, available)
            volume_draw()
        elseif changed then
            -- Repaint only when the data actually moved, so the common case
            -- (nothing changed) causes no visible update at all.
            volume_render_devices(current, available)
        end
    end)
end

local function volume_scroll(env)
    local delta = env.SCROLL_DELTA
    sbar.exec('osascript -e "set volume output volume (output volume of (get volume settings) + ' .. delta .. ')"')
end

popups.register("volume", volume_collapse_details)

volume_icon:subscribe("mouse.clicked", volume_toggle_details)
volume_icon:subscribe("mouse.scrolled", volume_scroll)
volume_percent:subscribe("mouse.clicked", volume_toggle_details)
volume_percent:subscribe("mouse.scrolled", volume_scroll)

-- Kept, but it is not load-bearing: delivery is unreliable (see helpers/popups).
volume_percent:subscribe("mouse.exited.global", volume_collapse_details)

-- Reaching this widget dismisses anything else that is open.
local function volume_entered()
    popups.close_all("volume")
    popups.hover(true)
end
local function volume_exited()
    popups.hover(false)
end

volume_icon:subscribe("mouse.entered", volume_entered)
volume_percent:subscribe("mouse.entered", volume_entered)
volume_icon:subscribe("mouse.exited", volume_exited)
volume_percent:subscribe("mouse.exited", volume_exited)

-- The slider lives in the popup; hovering it must not let the idle timer run.
volume_slider:subscribe("mouse.entered", function() popups.hover(true) end)
volume_slider:subscribe("mouse.exited", function() popups.hover(false) end)
