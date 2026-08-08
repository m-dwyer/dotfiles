-- Add the sketchybar module to the package cpath
package.cpath = package.cpath .. ";" .. os.getenv("HOME") .. "/.local/share/sketchybar_lua/?.so"

-- Build the C helpers only when the binary is missing.
--
-- `make` no-ops when bin/menus is newer than menus.c, but it is still a blocking
-- fork (shell + make + stat) on every bar load and reload. The binary is
-- excluded from chezmoi via .chezmoiignore ("**/bin"), so it genuinely only
-- needs building on a fresh machine or after menus.c changes — in which case
-- delete bin/menus and reload.
local menus_bin = os.getenv("HOME") .. "/.config/sketchybar/helpers/menus/bin/menus"
local handle = io.open(menus_bin, "r")
if handle then
  handle:close()
else
  os.execute("(cd helpers && make)")
end
