-- Minimal AeroSpace query helpers.
--
-- Everything else that used to live here (dump, explode, get_workspaces,
-- get_monitors, get_workspaces_on_monitor, get_visible_workspace_on_monitor,
-- is_workspace_selected) was either never called or has been replaced by cached
-- event state in items/spaces.lua. Each one was a blocking io.popen, and
-- is_workspace_selected in particular was O(monitors) subprocesses per call.

function parse_string_to_table(s)
    local result = {}
    for line in s:gmatch("([^\n]+)") do
        table.insert(result, line)
    end
    return result
end

-- Blocking, but called exactly once at bar load to seed the initial highlight.
-- Thereafter items/spaces.lua tracks the focused workspace from the
-- aerospace_workspace_changed event payload instead of re-querying.
function get_current_workspace()
    local file = io.popen("aerospace list-workspaces --focused")
    local result = file:read("*a")
    file:close()

    return parse_string_to_table(result)[1]
end
