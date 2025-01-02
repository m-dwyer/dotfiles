local colors = require("colors")

local front_app = sbar.add("item", {
    icon = {
      drawing = false
    },
    -- position = "left",
    label = {
      font = {
        style = "Black",
        size = 12.0,
      }
    },
    background = {
      color = colors.bg2
    },
    position = "left"
  })
  
  front_app:subscribe("front_app_switched", function(env)
    front_app:set({
      label = {
        string = env.INFO
      }
    })
  
    -- Or equivalently:
    -- sbar.set(env.NAME, {
    --   label = {
    --     string = env.INFO
    --   }
    -- })
  end)