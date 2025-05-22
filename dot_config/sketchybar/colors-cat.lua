return {
    black = 0xff181926,
    white = 0xffcad3f5,
    red = 0xffed8796,
    green = 0xffa6da95,
    blue = 0xff8aadf4,
    yellow = 0xffeed49f,
    pink = 0xfff5bde6,
    orange = 0xfff5a97f,
    magenta = 0xffc6a0f6,
    grey = 0xff939ab7,
    transparent = 0x00000000,
  
    bar = {
        color = 0xa024273a
    },
    icon = {
        color = 0xffcad3f5,
    },
    label = {
        color = 0xa024273a,
    },
    bg1 = 0x903c3e4f,
    bg2 = 0x90494d64,
    popup = {
      background_color = 0xff24273a,
      border_color = 0xffcad3f5
    },
    shadow_color = 0xff181926,
    with_alpha = function(color, alpha)
      if alpha > 1.0 or alpha < 0.0 then return color end
      return (color & 0x00ffffff) | (math.floor(alpha * 255.0) << 24)
    end,
  }