#!/usr/bin/env bash

#   Update all Wallpapers
function wallpaper() {
	wallpaper_path="$1"
	echo "Setting wallpaper to $wallpaper_path" 
	osascript -e 'tell application "Finder" to set desktop picture to POSIX file "'"$wallpaper_path"'"' 
	ret=$? 
	if [ $ret == "0" ]; then 
		echo "Wallpaper set successfully " 
	else 
		echo "Operation failed." 
	fi
}

WALLPAPER_DIR=$(dirname "$(realpath "$0")")
BASE_FILE=$(basename "$1")

wallpaper "${WALLPAPER_DIR}/${BASE_FILE}"
