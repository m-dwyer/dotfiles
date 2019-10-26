#!/usr/bin/env sh

if xwininfo -tree -root | grep "(\"dropdown_calc\" ";
then
	echo "Window detected."
	i3-msg "[instance=\"dropdown_calc\"] scratchpad show; [instance=\"dropdown_calc\"] move position center"
else
	echo "Spawning calc"
	i3-msg "exec --no-startup-id urxvt -name dropdown_calc $@ -e bc -lq"
fi
