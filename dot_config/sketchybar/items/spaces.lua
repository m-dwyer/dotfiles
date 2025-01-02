local colors = require("colors")
local icons = require("icons")
local settings = require("settings")
-- local app_icons = require("helpers.app_icons")

local spaces = {}
local workspaces = {
  ["1"] = { icon = "1 󰖟", name = "Web" },
  ["2"] = { icon = "2 ", name = "Code" },
  ["3"] = { icon = "3 󰽴", name = "Music" },
  ["4"] = { icon = "4 ", name = "Files" },
  ["5"] = { icon = "5 ", name = "Terminal" },
  ["6"] = { icon = "6 󰦕", name = "Productivity" },
  ["7"] = { icon = "7 ", name = "Misc" },
}

-- Display order of workspaces
local workspaceOrder = { "1", "2", "3", "4", "5", "6", "7" }

local current_workspace = get_current_workspace()

local function split(str, sep)
  local result = {}
  local regex = ("([^%s]+)"):format(sep)
  for each in str:gmatch(regex) do
    table.insert(result, each)
  end
  return result
end

for i, key in ipairs(workspaceOrder) do
  local workspace = workspaces[key]
  local selected = key == current_workspace
  local space = sbar.add("item", "item." .. i, {
    icon = {
      font = {
        family = settings.font.numbers,
        size = 14
      },
      string = workspace.icon,
      padding_left = settings.items.padding.left,
      padding_right = settings.items.padding.left / 2,
      color = settings.items.default_color(i),
      highlight_color = settings.items.highlight_color(i),
      highlight = selected,
    },
    label = {
      string = workspace.name,
      width = selected and "dynamic" or 0,
      padding_right = 10,
      color = settings.items.default_color(i),
      highlight_color = settings.items.highlight_color(i),
      font = settings.icons,
      y_offset = -1,
      highlight = selected,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = settings.items.colors.background,
      border_width = 1,
      height = settings.items.height,
      border_color = selected and settings.items.highlight_color(i) or settings.items.default_color(i)
    },
    popup = {
      background = {
        border_width = 5,
        border_color = colors.black
      }
    }
  })

  spaces[i] = space

  space:subscribe("mouse.entered", function(env)
    sbar.animate("tanh", 30, function()
      spaces[i]:set({ label = { width = "dynamic" } })
    end)
  end)

  --- Define the icons for open apps on each space initially
  -- sbar.exec("aerospace list-windows --workspace " .. i .. " --format '%{app-name}' --json ", function(apps)
  --   local icon_line = ""
  --   local no_app = true
  --   for i, app in ipairs(apps) do
  --     no_app = false
  --     local app_name = app["app-name"]
  --     -- local lookup = app_icons[app_name]
  --     local icon = ((lookup == nil) and app_icons["default"] or lookup)
  --     icon_line = icon_line .. " " .. icon
  --   end

  --   if no_app then
  --     icon_line = " —"
  --   end

  --   sbar.animate("tanh", 10, function()
  --     space:set({
  --       label = icon_line
  --     })
  --   end)
  -- end)

  -- Padding space between each item
  sbar.add("item", "item." .. i .. "padding", {
    script = "",
    width = settings.items.gap
  })

  -- Item popup
  local space_popup = sbar.add("item", {
    position = "popup." .. space.name,
    padding_left = 5,
    padding_right = 0,
    background = {
      drawing = true,
      image = {
        corner_radius = 9,
        scale = 0.2
      }
    }
  })

  space:subscribe("aerospace_workspace_changed", function(env)
    local selected = env.FOCUSED_WORKSPACE == key
    
    sbar.animate("tanh", 30, function()
      space:set({ label = { width = selected and "dynamic" or 0 } })
    end)

    space:set({
      icon = {
        highlight = selected
      },
      label = {
        highlight = selected,
      },
      background = {
        border_color = selected and settings.items.highlight_color(i) or settings.items.default_color(i)
      }
    })
  end)

  space:subscribe("mouse.clicked", function(env)
    local SID = split(env.NAME, ".")[2]
    if env.BUTTON == "other" then
      -- space_popup:set({
      --   background = {
      --     image = "item." .. SID
      --   }
      -- })
      space:set({
        popup = {
          drawing = "toggle"
        }
      })
    else
      sbar.exec("aerospace workspace " .. SID)
    end
  end)

  space:subscribe("mouse.exited", function(env)
    local exitedWorkspace = string.match(env.NAME, "item%.([%w_]+)")
    local current = get_current_workspace()

    space:set({
      popup = {
        drawing = false
      }
    })
    sbar.animate("tanh", 30, function()
      spaces[i]:set({ label = { width = exitedWorkspace == current and "dynamic" or 0 } })
    end)
  end)
end

local space_window_observer = sbar.add("item", {
  drawing = false,
  updates = true
})

-- Event handles
space_window_observer:subscribe("space_windows_change", function(env)
  for i, workspace in ipairs(workspaces) do
    sbar.exec("aerospace list-windows --workspace " .. i .. " --format '%{app-name}' --json ", function(apps)
      local icon_line = ""
      local no_app = true
      for i, app in ipairs(apps) do
        no_app = false
        local app_name = app["app-name"]
        local lookup = app_icons[app_name]
        local icon = ((lookup == nil) and app_icons["default"] or lookup)
        icon_line = icon_line .. " " .. icon
      end

      if no_app then
        icon_line = " —"
      end

      sbar.animate("tanh", 10, function()
        spaces[i]:set({
          label = icon_line
        })
      end)
    end)
  end
end)

space_window_observer:subscribe("aerospace_focus_change", function(env)
  for i, workspace in ipairs(workspaces) do
    sbar.exec("aerospace list-windows --workspace " .. i .. " --format '%{app-name}' --json ", function(apps)
      local icon_line = ""
      local no_app = true
      for i, app in ipairs(apps) do
        no_app = false
        local app_name = app["app-name"]
        local lookup = app_icons[app_name]
        local icon = ((lookup == nil) and app_icons["default"] or lookup)
        icon_line = icon_line .. " " .. icon
      end

      if no_app then
        icon_line = " —"
      end

      sbar.animate("tanh", 10, function()
        spaces[i]:set({
          label = icon_line
        })
      end)
    end)
  end
end)
