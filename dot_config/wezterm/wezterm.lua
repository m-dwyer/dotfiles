-- Pull in WezTerm API
local wezterm = require 'wezterm'

-- Utility functions
local window_background_opacity = 0.9
local function toggle_window_background_opacity(window)
    local overrides = window:get_config_overrides() or {}
    if not overrides.window_background_opacity then
        overrides.window_background_opacity = 1.0
    else
        overrides.window_background_opacity = nil
    end
    window:set_config_overrides(overrides)
end
wezterm.on("toggle-window-background-opacity", toggle_window_background_opacity)

local function toggle_ligatures(window)
  local overrides = window:get_config_overrides() or {}
  if not overrides.harfbuzz_features then
    overrides.harfbuzz_features = { 'calt=0', 'clig=0', 'liga=0' }
  else
    overrides.harfbuzz_features = nil
  end
  window:set_config_overrides(overrides)
end
wezterm.on("toggle-ligatures", toggle_ligatures)


-- Initialize actual config
local config = {}
if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Appearance
config.font_size = 22.0
config.color_scheme = "Catppuccin Macchiato"
config.window_background_opacity = 0.9
config.macos_window_background_blur = 10
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.native_macos_fullscreen_mode = false
config.use_fancy_tab_bar = false
config.front_end="WebGpu"

-- Keybindings
config.keys = {
  {
    key = 'A',
    mods = 'CTRL|SHIFT',
    action = wezterm.action.QuickSelect,
  },
  {
    key = "O",
    mods = 'CTRL|SHIFT',
    action = wezterm.action.EmitEvent("toggle-window-background-opacity"),
  },
  {
    key = "E",
    mods = 'CTRL|SHIFT',
    action = wezterm.action.EmitEvent("toggle-ligatures"),
  },
  -- Quickly open config file with common macOS keybind
  {
    key = ',',
    mods = 'SUPER',
    action = wezterm.action.SpawnCommandInNewWindow({
      cwd = os.getenv 'WEZTERM_CONFIG_DIR',
      args = { os.getenv 'SHELL', '-c', '$VISUAL $WEZTERM_CONFIG_FILE' },
    }),
  },
}

-- Return config to WezTerm
return config
