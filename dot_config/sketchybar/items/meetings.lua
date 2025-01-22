local settings = require("settings")
local colors = require("colors")

local calendar_name = "Home"

local expected_meeting_links = {
    "https://meet.google.com/[%w%-]+[%w%-]+[%w%-]+",
    "https://[%w]+.zoom.us/j/[%w]+"
}

local popup_width = 100

local meetings = sbar.add("item", "widgets.meetings", {
    icon = {
        color = colors.white,
        padding_left = 8,
        font = {
            size = 22.0
        }
    },
    label = {
        color = colors.white,
        padding_right = 8,
        width = popup_width,
        align = "right",
        font = {
            family = settings.icons
        }
    },
    position = "right",
    width =  "dynamic",
    update_freq = 30,
    padding_left = 1,
    padding_right = 1,
    background = {
        color = colors.bg2,
        border_color = colors.rainbow[#colors.rainbow],
        border_width = 1
    },
    popup = {
        align = "center"
    }
})

local meetings_bracket = sbar.add("bracket", "widgets.meetings.bracket",{ meetings.name }, {
    background = {
        color = colors.bg1,
        border_color = colors.rainbow[#colors.rainbow - 3],
        border_width = 1
    },
    popup = {
        align = "center",
        drawing = false
    }
})

-- Padding item required because of bracket
sbar.add("item", {
    position = "right",
    width = settings.group_paddings
})

local function meetings_collapse_details()
    local drawing = meetings_bracket:query().popup.drawing == "on"
    if not drawing then
        return
    end

    meetings_bracket:set({
        popup = {
            drawing = false
        }
    })
end

local function fetch_meetings(_)
    print("fetching meetings..")
    sbar.remove('/meetings.meeting\\.*/')
    sbar.exec("icalBuddy -nc -b '' -ic '" .. calendar_name .. "' -iep 'title,datetime,notes' -po 'title,datetime,notes' -ps '/;;/' -ea eventsToday", function(info)
        local parsed_data = parse_calendar(info)
        local counter = 0
        for i, entry in ipairs(parsed_data) do
            -- print("Event title:", entry.title)
            -- print("\tEvent time: ", entry.time or "")
            -- print("\tEvent note:", entry.note or "")
            -- print("\tEvent link: ", entry.link or "")

            if counter == 0 then
                meetings:set({
                    label = string.sub(entry.title, 1, 15)
                })
            end

            local meeting = sbar.add("item", "meetings.meeting." .. i, {
                position = "popup." .. meetings_bracket.name,
                width = "dynamic",
                align = "center",
                label = {
                    string = string.sub(entry.title, 1, 15) .. " " .. (entry.time or ""):gsub("[^%w:-]", ""),
                    width = "dynamic"
                }
            })

            if entry.link then
                meeting:set({
                    click_script = "open " .. entry.link
                })
                meeting:subscribe("mouse.clicked", meetings_collapse_details)
            end

            counter = counter + 1
        end
    end)
end

local function meetings_toggle_details(env)
    local should_draw = meetings_bracket:query().popup.drawing == "off"

    if should_draw then
        meetings_bracket:set({
            popup = {
                drawing = true
            }
        })
        fetch_meetings()
    else
        meetings_collapse_details()
    end
end

local function stringify_block(block)
    local note_str = ""
    for i, line in ipairs(block) do
        note_str = note_str .. line .. "\r\n"
    end

    return note_str
end

local function find_meeting_link(input)
    local link = nil
    for i, link_regex in ipairs(expected_meeting_links) do
        link = string.match(input, link_regex)
        if link then
            break
        end
    end

    return link
end

function parse_calendar(input_string)
    local lines = {}
    for line in input_string:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local result = {}
    local current_block = {}

    local isNote = false

    local eventTitle = nil
    local eventTime = nil
    local eventNote = nil

    for i, line in ipairs(lines) do
        if isNote and line:match("^%s") then
            table.insert(current_block, line)
        else
            if isNote then
                local note_str = stringify_block(current_block)
                table.insert(result, {title = eventTitle, time = eventTime, note = note_str, link = find_meeting_link(note_str)})
                isNote = false
                current_block = {}
            end

            local t = {}
            local sep = ";;"
            for str in string.gmatch(line, "([^"..sep.."]+)") do
                table.insert(t, str)
            end

            eventTitle = t[1] or nil
            eventTime = t[2] or nil
            eventNote = t[3] or nil

            if eventNote then
                isNote = true
                table.insert(current_block, eventNote)
            end

            if i == #lines or not t[3] then
                local note_str = ""
                for i, line in ipairs(current_block) do
                    note_str = note_str .. line .. "\r\n"
                end
                table.insert(result, {title = eventTitle, time = eventTime, note = note_str, link = find_meeting_link(note_str)})
            end
        end
    end

    return result
end

local meeting_watcher = sbar.add("item", {update_freq = 60})
meeting_watcher:subscribe("routine", function()
    fetch_meetings()
end)

meetings:subscribe("mouse.clicked", meetings_toggle_details)
meetings:subscribe("mouse.exited.global", meetings_collapse_details)

-- Initial populate on load
fetch_meetings()