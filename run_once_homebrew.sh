#!/bin/bash

# Install required packages
brew bundle --no-lock --file=/dev/stdin <<EOF
tap "felixkratz/formulae"
tap "homebrew/bundle"
tap "homebrew/services"
tap "nikitabobko/tap"
tap "koekeishiya/formulae"
brew "yabai"
brew "chezmoi"
brew "lua"
brew "nowplaying-cli"
brew "switchaudio-osx"
brew "felixkratz/formulae/borders"
brew "felixkratz/formulae/sketchybar"
cask "aerospace"
cask "font-fira-code-nerd-font"
cask "font-hack-nerd-font"
cask "font-sf-pro"
cask "font-space-mono-nerd-font"
cask "hammerspoon"
brew "lsd"
brew "zoxide"
brew "btop"
brew "difftastic"
brew "gdu"
brew "ripgrep"
brew "fzf"
brew "lazydocker"
brew "yazi"
brew "mediainfo"
brew "spicetify-cli"
EOF