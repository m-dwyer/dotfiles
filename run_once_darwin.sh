#!/usr/bin/env bash

# Disable wallpaper to reveal desktop
defaults write com.apple.WindowManager "EnableStandardClickToShowDesktop" -bool "false" && killall WindowManager

# Displays have separate spaces -- required for yabai to run (for hiding Mac menu bar)
defaults write com.apple.spaces "spans-displays" -bool "true" && killall SystemUIServer