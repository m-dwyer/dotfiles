-- Pull in WezTerm API
local wezterm = require("wezterm")
local act = wezterm.action

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
		overrides.harfbuzz_features = { "calt=0", "clig=0", "liga=0" }
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
config.font_size = 16.0
config.color_scheme = "Catppuccin Macchiato"
config.window_background_opacity = 0.9
config.macos_window_background_blur = 10
config.window_decorations = "RESIZE"
config.hide_tab_bar_if_only_one_tab = true
config.native_macos_fullscreen_mode = false
config.use_fancy_tab_bar = false
config.front_end = "WebGpu"

-- Keybindings
config.keys = {
	{
		key = "A",
		mods = "CTRL|SHIFT",
		action = wezterm.action.QuickSelect,
	},
	{
		key = "O",
		mods = "CTRL|SHIFT",
		action = wezterm.action.EmitEvent("toggle-window-background-opacity"),
	},
	{
		key = "E",
		mods = "CTRL|SHIFT",
		action = wezterm.action.EmitEvent("toggle-ligatures"),
	},
	-- Quickly open config file with common macOS keybind
	{
		key = ",",
		mods = "SUPER",
		action = wezterm.action.SpawnCommandInNewWindow({
			cwd = os.getenv("WEZTERM_CONFIG_DIR"),
			args = { os.getenv("SHELL"), "-c", "$VISUAL $WEZTERM_CONFIG_FILE" },
		}),
	},
	-- Clears the scrollback and viewport, and then sends CTRL-L to ask the
	-- shell to redraw its prompt
	{
		key = "K",
		mods = "CTRL|SHIFT",
		action = act.Multiple({
			act.ClearScrollback("ScrollbackAndViewport"),
			act.SendKey({ key = "L", mods = "CTRL" }),
		}),
	},
}

-- Agent workflow ------------------------------------------------------------

config.scrollback_lines = 500000
config.audible_bell = "Disabled"

-- Desktop notification on the bell; emit with `printf '\a'`
wezterm.on("bell", function(window, pane)
	window:toast_notification("wezterm", "done: " .. pane:get_title(), nil, 4000)
end)

-- Needs OSC 133 semantic zones (wezterm.sh in .zshrc)
wezterm.on("copy-last-output", function(window, pane)
	local zones = pane:get_semantic_zones("Output")
	local zone = zones[#zones]
	if not zone then
		return
	end
	window:copy_to_clipboard(pane:get_text_from_semantic_zone(zone), "Clipboard")
	window:toast_notification("wezterm", "copied last command output", nil, 2000)
end)

wezterm.on("format-tab-title", function(tab)
	local cwd = tab.active_pane.current_working_dir
	local label = tab.active_pane.title
	if cwd then
		-- current_working_dir is a string on older builds, a Url object on newer
		local p = type(cwd) == "userdata" and cwd.file_path or tostring(cwd)
		label = p:gsub("/$", ""):match("[^/]+$") or label
	end
	return " " .. tab.tab_index + 1 .. ": " .. label .. " "
end)

-- file.ts:42[:9] and git shas
-- Panes in this domain run inside a devcontainer. A repo's own .devcontainer wins;
-- otherwise the generic sandbox config applies. `devcontainer up` is the caller's
-- job (wtp does it) because this hook only wraps the command.
config.exec_domains = {
	wezterm.exec_domain("devcontainer", function(cmd)
		local dir = cmd.cwd or wezterm.home_dir
		local args = { "devcontainer", "exec", "--workspace-folder", dir }
		local own = io.open(dir .. "/.devcontainer/devcontainer.json")
		if own then
			own:close()
		else
			table.insert(args, "--config")
			table.insert(args, wezterm.home_dir .. "/.config/devcontainer/devcontainer.json")
		end
		for _, arg in ipairs(cmd.args or { "bash", "-l" }) do
			table.insert(args, arg)
		end
		cmd.args = args
		return cmd
	end),
}

-- `wtp` builds the workspace with `wezterm cli` and then emits this user var to
-- switch to it. Switching has to happen here: there is no CLI verb for it, and
-- pane:split() silently no-ops on unix-domain panes.
wezterm.on("user-var-changed", function(_, _, name, value)
	if name == "open_project" then
		wezterm.mux.set_active_workspace(value)
	end
end)

config.quick_select_patterns = {
	[==[[^\s'"()\[\]]+\.[a-zA-Z]+:\d+(:\d+)?]==],
	[[\b[0-9a-f]{7,40}\b]],
}

-- Panes outlive the GUI; attach with `wezterm connect unix`
config.unix_domains = { { name = "unix" } }

config.leader = { key = "b", mods = "CTRL", timeout_milliseconds = 2000 }

-- Hint line while the leader or a key table is pending. Renders in the tab bar,
-- so it is only visible when the tab bar is showing.
local leader_hints =
	"h/j/k/l or arrows pane   \\ split right   - split down   z zoom   p pick pane   [ / ] prompt   w workspace   W new workspace   r resize   o copy last output"
local key_table_hints = { resize = "h/j/k/l resize   Esc done" }

config.status_update_interval = 100

wezterm.on("update-status", function(window)
	local table_name = window:active_key_table()
	local hint = table_name and key_table_hints[table_name]
	local label = table_name and table_name:upper() or "LEADER"
	if not hint and window:leader_is_active() then
		hint = leader_hints
	end
	if not hint then
		window:set_right_status("")
		return
	end
	window:set_right_status(wezterm.format({
		{ Background = { Color = "#c6a0f6" } },
		{ Foreground = { Color = "#24273a" } },
		{ Attribute = { Intensity = "Bold" } },
		{ Text = " " .. label .. " " },
		{ Background = { Color = "#363a4f" } },
		{ Foreground = { Color = "#cad3f5" } },
		{ Attribute = { Intensity = "Normal" } },
		{ Text = "  " .. hint .. " " },
	}))
end)

for _, key in ipairs({
	-- Ctrl+B twice sends a literal Ctrl+B (nvim page-up, zsh backward-char)
	{ key = "b", mods = "LEADER|CTRL", action = act.SendKey({ key = "b", mods = "CTRL" }) },
	{ key = "|", mods = "LEADER|SHIFT", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "\\", mods = "LEADER", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "-", mods = "LEADER", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	-- AeroSpace owns CTRL|SHIFT arrows (workspace prev/next), so pane navigation
	-- lives on the home row and WezTerm releases the whole arrow cluster.
	{ key = "UpArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "DownArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "LeftArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "RightArrow", mods = "CTRL|SHIFT", action = act.DisableDefaultAssignment },
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "LeftArrow", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "DownArrow", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "UpArrow", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "RightArrow", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "[", mods = "LEADER", action = act.ScrollToPrompt(-1) },
	{ key = "]", mods = "LEADER", action = act.ScrollToPrompt(1) },
	{ key = "z", mods = "LEADER", action = act.TogglePaneZoomState },
	{ key = "p", mods = "LEADER", action = act.PaneSelect({ mode = "Activate" }) },
	{ key = "w", mods = "LEADER", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
	{ key = "o", mods = "LEADER", action = act.EmitEvent("copy-last-output") },
	{ key = "r", mods = "LEADER", action = act.ActivateKeyTable({ name = "resize", one_shot = false }) },
	{
		key = "W",
		mods = "LEADER|SHIFT",
		action = act.PromptInputLine({
			description = "New workspace name:",
			action = wezterm.action_callback(function(window, pane, line)
				if line and line ~= "" then
					window:perform_action(act.SwitchToWorkspace({ name = line }), pane)
				end
			end),
		}),
	},
}) do
	table.insert(config.keys, key)
end

config.key_tables = {
	resize = {
		{ key = "h", action = act.AdjustPaneSize({ "Left", 3 }) },
		{ key = "l", action = act.AdjustPaneSize({ "Right", 3 }) },
		{ key = "k", action = act.AdjustPaneSize({ "Up", 3 }) },
		{ key = "j", action = act.AdjustPaneSize({ "Down", 3 }) },
		{ key = "LeftArrow", action = act.AdjustPaneSize({ "Left", 3 }) },
		{ key = "RightArrow", action = act.AdjustPaneSize({ "Right", 3 }) },
		{ key = "UpArrow", action = act.AdjustPaneSize({ "Up", 3 }) },
		{ key = "DownArrow", action = act.AdjustPaneSize({ "Down", 3 }) },
		{ key = "Escape", action = "PopKeyTable" },
	},
}

-- Return config to WezTerm
return config
