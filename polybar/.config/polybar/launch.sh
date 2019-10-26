#!/usr/bin/env sh

killall -w -q polybar

if type "xrandr"; then
	for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
		MONITOR=$m polybar -c ~/.config/polybar/config -r mybar 2> /tmp/polybar_log &
	done
else
	polybar -c ~/.config/polybar/config -r mybar 2> /tmp/polybar_log &
fi

