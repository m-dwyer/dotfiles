#!/usr/bin/env bash

# Disable wallpaper to reveal desktop
defaults write com.apple.WindowManager "EnableStandardClickToShowDesktop" -bool "false" && killall WindowManager