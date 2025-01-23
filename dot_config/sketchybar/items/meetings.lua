local settings = require("settings")
local colors = require("colors")

-- Widget configuration
local calendar_name = "Home"
local calendar_db = os.getenv("HOME") .. "/Library/Group\\ Containers/group.com.apple.calendar/Calendar.sqlitedb"
local calendar_refresh = 180

local expected_meeting_links = {
    "https://meet.google.com/[%w%-]+[%w%-]+[%w%-]+",
    "https://[%w]+.zoom.us/j/[%w]+"
}

local meetings = sbar.add("item", "widgets.meetings", {
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
        },
        max_chars = 15,
        scroll_texts = "off",
    },
    background = {
        color = colors.bg2,
        border_color = colors.rainbow[#colors.rainbow],
        border_width = 1
    },
    update_freq = calendar_refresh,
    popup = {
        align = "center"
    }
})

-- Padding item required because of bracket
sbar.add("item", {
    position = "right",
    width = settings.group_paddings
})

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

local function parse_calendar(input)
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

    return result
end

local function parse_datetime(datetime)
    local year, month, day, hour, min, sec = datetime:match("(%d+)-(%d+)-(%d+) (%d+):(%d+):(%d+)")
    local parsed_datetime = os.time({
        year = tonumber(year),
        month = tonumber(month),
        day = tonumber(day),
        hour = tonumber(hour),
        min = tonumber(min),
        sec = tonumber(sec),
    })

    return parsed_datetime
end

local function calculate_time_until(datetime)
    local parsed_datetime = parse_datetime(datetime)

    -- Get the current time
    local current_time = os.time()

    -- Calculate the difference in seconds
    local diff_seconds = os.difftime(parsed_datetime, current_time)

    -- Convert the difference to minutes
    local diff_minutes = diff_seconds / 60
    local diff_hours = diff_minutes / 60

    local time_until = ""
    if diff_hours >= 1 then
        time_until = math.tointeger(math.floor(diff_hours+0.5)) .. " hr"
    elseif diff_minutes > 0 then
        time_until = math.tointeger(math.ceil(diff_minutes+0.5))  .. " min"
    else
        time_until = "now"
    end

    return time_until
end

local function fetch_meetings(_)
    local calendar_script=[=[
sqlite3 ${calendar_db} << EOF
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
  AND (
    -- Include ongoing events
    (DateTime(ci.start_date + 978307200, 'unixepoch') <= DateTime('now')
     AND DateTime(ci.end_date + 978307200, 'unixepoch') >= DateTime('now'))
    OR
    -- Include events starting later today
    (DateTime(ci.start_date + 978307200, 'unixepoch') >= DateTime('now')
     AND DateTime(ci.start_date + 978307200, 'unixepoch') < DateTime('now', '+1 day', 'start of day'))
  )
ORDER BY
  ci.start_date;
EOF
    ]=]

    vars = {calendar_db = calendar_db, calendar_name = calendar_name}
    calendar_script = (calendar_script:gsub('($%b{})', function(w)
        return vars[w:sub(3, -2)] or w
      end))

    sbar.remove('/meetings.meeting\\.*/')
    sbar.exec(calendar_script, function(info)
        local parsed_data = parse_calendar(info)
        local counter = 0
        for i, entry in ipairs(parsed_data) do
            if counter == 0 then
                meetings:set({
                    label = {
                        string = entry.summary .. " (" .. calculate_time_until(entry.startDate) .. ")"
                    }
                })
            end

            local meeting_range = ""

            if entry.startDate then
                local start_date = os.date("*t", parse_datetime(entry.startDate))
                meeting_range = meeting_range .. string.format("%02d",start_date.hour) .. ":" .. string.format("%02d",start_date.min)
            end

            if entry.endDate then
                local end_date = os.date("*t", parse_datetime(entry.endDate))
                meeting_range = meeting_range .. "-" .. string.format("%02d",end_date.hour) .. ":" .. string.format("%02d", end_date.min)
            end

            local meeting = sbar.add("item", "meetings.meeting." .. i, {
                position = "popup." .. meetings.name,
                scroll_texts = "off",
                width = 200,
                align = "center",
                label = {
                    string = meeting_range .. " " .. entry.summary,
                    -- width = "dynamic"
                    max_chars = 25,
                }
            })

            meeting:subscribe("mouse.entered", function(env)
                meeting:set({
                    scroll_texts = "on"
                })
            end)

            if entry.link then
                meeting:set({
                    click_script = "open " .. entry.link
                })
                meeting:subscribe("mouse.clicked", function(env)
                    meetings:set({
                        popup = {
                            drawing = "toggle"
                        }
                    })
                end)
            end

            counter = counter + 1
        end
    end)
end

local meeting_watcher = sbar.add("item", {update_freq = calendar_refresh})
meeting_watcher:subscribe("routine", function()
    fetch_meetings()
end)

meetings:subscribe("mouse.clicked", function(env)
    local drawing = meetings:query().popup.drawing
    meetings:set({
        popup = {
            drawing = "toggle"
        }
    })

    if drawing == "off" then
        fetch_meetings()
    end
end)

meetings:subscribe("mouse.exited.global", function(env)
    meetings:set({
        popup = {
            drawing = "toggle"
        }
    })
end)

meetings:subscribe("mouse.entered", function(env)
    meetings:set({
        label = {
            scroll_texts = "on",
            scroll_duration = 50,
            max_chars = 15
        }
    })
end)

meetings:subscribe("mouse.exited", function(env)
    meetings:set({
        label = {
            scroll_texts = "off",
            max_chars = 15
        }
    })
end)

-- Initial populate on load
fetch_meetings()