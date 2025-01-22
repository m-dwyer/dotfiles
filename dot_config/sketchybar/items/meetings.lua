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

local function parse_calendar_new(input)
    print("getting cal events")
    print("input is: " .. input)
    local lines = {}
    for line in input:gmatch("[^\r\n]+") do
        table.insert(lines, line)
    end

    local sep = "|"

    local result = {}
    for i, line in ipairs(lines) do
        local line_split = {}
        local idx = 1
        for str in string.gmatch(line, "([^"..sep.."]+)") do
            table.insert(line_split, idx, str)
            idx = idx + 1
        end

        local eventSummary = line_split[1]
        local eventStart = line_split[2]
        local eventEnd = line_split[3]
        local eventNote = line_split[4]

        table.insert(result, {summary = eventSummary, startDate = eventStart, endDate = eventEnd, note = eventNote, link = find_meeting_link(eventNote)})
    end

    for i, event in ipairs(result) do
        print("i = " .. i)
        print("event summary: " .. event.summary)
        print("event start date: " .. event.startDate or "")
        print("event end date: " .. event.endDate)
        print("event note: " .. event.note)
    end

    return result
end

local function fetch_meetings_new(_)
sql=[=[
  SELECT * FROM users WHERE username='$username';
]=]

    local calendar_script=[=[
sqlite3 ~/Library/Group\ Containers/group.com.apple.calendar/Calendar.sqlitedb << EOF
.mode list
.separator |
SELECT
  ci.summary AS summary,
  DateTime(ci.start_date + 978307200, 'unixepoch', 'localtime') as start_date,
  DateTime(ci.end_date + 978307200, 'unixepoch', 'localtime') as end_date,
  REPLACE(REPLACE(ci.description, CHAR(13), '\r'), CHAR(10), '\n') as notes,
  c.title as title
FROM
  Calendar c
JOIN
  CalendarItem ci ON c.rowid = ci.calendar_id
WHERE
  c.title = '${calendar_name}'
ORDER BY
  start_date;
EOF
    ]=]

    vars = {calendar_name = calendar_name}
    calendar_script = (calendar_script:gsub('($%b{})', function(w)
        return vars[w:sub(3, -2)] or w
      end))

    print("fetching meetings..")
    sbar.remove('/meetings.meeting\\.*/')
    sbar.exec(calendar_script, function(info)
        print("---------------- output ------:")
        print(info)
        local parsed_data = parse_calendar_new(info)
        local counter = 0
        for i, entry in ipairs(parsed_data) do
            if counter == 0 then
                meetings:set({
                    label = string.sub(entry.summary, 1, 15)
                })
            end

            local meeting = sbar.add("item", "meetings.meeting." .. i, {
                position = "popup." .. meetings_bracket.name,
                width = "dynamic",
                align = "center",
                label = {
                    string = (entry.startDate or "") .. " " .. string.sub(entry.summary, 1, 15),
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
        fetch_meetings_new()
    else
        meetings_collapse_details()
    end
end

local meeting_watcher = sbar.add("item", {update_freq = 60})
meeting_watcher:subscribe("routine", function()
    fetch_meetings_new()
end)

meetings:subscribe("mouse.clicked", meetings_toggle_details)
meetings:subscribe("mouse.exited.global", meetings_collapse_details)

-- Initial populate on load
fetch_meetings_new()