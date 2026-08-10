local icons = require("icons")
local colors = require("colors-cat")
local settings = require("settings-cat")
local popups = require("helpers.popups")

local battery = sbar.add("item", "widgets.battery", {
    position = "right",
    icon = {
        font = {
            style = settings.font.style_map["Regular"],
            size = 19.0
        }
    },
    label = {
        font = {
            family = settings.font.numbers
        }
    },
    update_freq = 180,
    popup = {
        align = "center"
    }
})

local remaining_time = sbar.add("item", {
    position = "popup." .. battery.name,
    icon = {
        string = "Time remaining:",
        width = 100,
        align = "left"
    },
    label = {
        string = "??:??h",
        width = 100,
        align = "right"
    }
})

battery:subscribe({"routine", "power_source_change", "system_woke"}, function()
    sbar.exec("pmset -g batt", function(batt_info)
        local icon = "!"
        local label = "?"

        local found, _, charge = batt_info:find("(%d+)%%")
        if found then
            charge = tonumber(charge)
            label = charge .. "%"
        end

        local color = colors.green
        local charging, _, _ = batt_info:find("AC Power")

        if charging then
            icon = icons.battery.charging
        else
            if found and charge > 80 then
                icon = icons.battery._100
            elseif found and charge > 60 then
                icon = icons.battery._75
            elseif found and charge > 40 then
                icon = icons.battery._50
            elseif found and charge > 20 then
                icon = icons.battery._25
                color = colors.orange
            else
                icon = icons.battery._0
                color = colors.red
            end
        end

        local lead = ""
        if found and charge < 10 then
            lead = "0"
        end

        battery:set({
            icon = {
                string = icon,
                color = color
            },
            label = {
                string = lead .. label
            }
        })
    end)
end)

local function battery_collapse_details()
    local drawing = battery:query().popup.drawing == "on"
    if not drawing then
        return
    end
    popups.disarm()
    battery:set({
        popup = {
            drawing = false
        }
    })
end

battery:subscribe("mouse.clicked", function(env)
    local should_draw = battery:query().popup.drawing == "off"
    if should_draw then
        battery:set({
            popup = {
                drawing = true
            }
        })
        popups.arm()
        sbar.exec("pmset -g batt", function(batt_info)
            local found, _, remaining = batt_info:find(" (%d+:%d+) remaining")
            local label = found and remaining .. "h" or "N/A"
            remaining_time:set({
                label = label
            })
        end)
    else
        battery_collapse_details()
    end
end)

popups.register("battery", battery_collapse_details)

-- Kept, but it is not load-bearing: delivery is unreliable (see helpers/popups).
battery:subscribe("mouse.exited.global", battery_collapse_details)

-- Reaching this widget dismisses anything else that is open.
battery:subscribe("mouse.entered", function()
    popups.close_all("battery")
    popups.hover(true)
end)
battery:subscribe("mouse.exited", function()
    popups.hover(false)
end)

-- The popup row itself, so reading it does not advance the idle timer.
remaining_time:subscribe("mouse.entered", function() popups.hover(true) end)
remaining_time:subscribe("mouse.exited", function() popups.hover(false) end)

sbar.add("bracket", "widgets.battery.bracket", {battery.name}, {
    background = {
        color = colors.bg2,
        border_color = colors.bg1,
        border_width = 1
    }
})

sbar.add("item", "widgets.battery.padding", {
    position = "right",
    width = settings.group_paddings
})