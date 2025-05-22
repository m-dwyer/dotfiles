local colors = require("colors-cat")

local front_app = sbar.add("item", {
    icon = {
      drawing = false
    },
    -- position = "left",
    label = {
      padding_left = 15,
      padding_right = 15,
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