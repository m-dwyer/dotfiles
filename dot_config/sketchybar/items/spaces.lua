local colors = require("colors-cat")
local icons = require("icons")
local settings = require("settings-cat")

local workspacesConfig = require("workspaces")
local popups = require("helpers.popups")

local spaces = {}

local workspaces = workspacesConfig.workspaces
local workspaceOrder = workspacesConfig.order

-- Queried once at startup, then kept current by the aerospace_workspace_changed
-- handler below. Avoids a blocking io.popen on every mouse event.
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
  local space = sbar.add("item", "space." .. i, {
    icon = {
      font = {
        family = settings.font.numbers
      },
      string = workspace.icon,
      padding_left = 15,
      padding_right = 15,
      color = colors.white,
      highlight_color = colors.red,
    },
    label = {
      padding_right = 20,
      color = colors.grey,
      highlight_color = colors.white,
      string = workspace.name,
      width = selected and "dynamic" or 0,
      font = settings.defaults.label.font,
    },
    padding_right = 1,
    padding_left = 1,
    background = {
      color = colors.bg1,
      border_width = 1,
      height = 26,
      border_color = colors.bg2
      -- border_color = selected and colors.white or colors.black
      -- border_color = selected and settings.items.highlight_color(i) or settings.items.default_color(i)
    },
    popup = {
      background = {
        border_width = 5,
        border_color = colors.black
      }
    }
  })

  spaces[i] = space

  -- Single item bracket for space items to achieve double border on highlight
  local space_bracket = sbar.add("bracket", { space.name }, {
    background = {
      color = colors.transparent,
      border_color = colors.bg2,
      height = 28,
      border_width = 2
    }
  })

    -- Padding space
    sbar.add("item", "space.padding." .. i, {
      script = "",
      width = settings.group_paddings,
    })

  space:subscribe("mouse.entered", function(env)
    -- Moving onto the workspace strip dismisses any open widget popup.
    popups.close_all()

    sbar.animate("tanh", 30, function()
      spaces[i]:set({ label = { width = "dynamic" } })
    end)
  end)

  -- sbar.add("bracket", { space.name }, {
  --   icon = {
  --     font = settings.font.text,
  --     padding_left = 15,
  --     padding_right = 15,
  --     label = {
  --       drawing = false
  --     },
  --     background = {
  --       color = colors.orange
  --     },
  --     associated_display = 'active',
  --     icon = {
  --       color = colors.white
  --     }
  --   }
  -- })

  -- Padding space between each item
  sbar.add("item", "space.padding." .. i, {
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
    current_workspace = env.FOCUSED_WORKSPACE
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
        border_color = selected and colors.white or colors.black
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
    local exitedWorkspace = string.match(env.NAME, "space%.([%w_]+)")
    local current = current_workspace

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
