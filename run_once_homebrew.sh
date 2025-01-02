#!/bin/bash

# Install required packages
brew bundle --no-lock --file=/dev/stdin <<EOF
tap "felixkratz/formulae"
tap "homebrew/bundle"
tap "homebrew/cask-versions"
tap "homebrew/services"
tap "nikitabobko/tap"
brew "chezmoi"
brew "lua"
brew "nowplaying-cli"
brew "switchaudio-osx"
brew "youtube-dl"
brew "felixkratz/formulae/borders"
brew "felixkratz/formulae/sketchybar"
cask "aerospace"
cask "font-fira-code-nerd-font"
cask "font-hack-nerd-font"
cask "font-sf-pro"
cask "font-space-mono-nerd-font"
cask "hammerspoon"
EOF