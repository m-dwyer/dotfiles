#!/usr/bin/env bash

# Install required packages
brew bundle --no-lock --file=/dev/stdin <<EOF

tap "homebrew/bundle"
tap "homebrew/services"

# Util
brew "chezmoi"

# Desktop
tap "felixkratz/formulae"
tap "nikitabobko/tap"
tap "koekeishiya/formulae"
brew "yabai"
brew "lua"
brew "felixkratz/formulae/borders"
brew "felixkratz/formulae/sketchybar"
cask "aerospace"
cask "hammerspoon"

brew "nowplaying-cli"
brew "switchaudio-osx"

# File Management
brew "yazi"
brew "mediainfo"
brew "zoxide"
brew "ripgrep"
brew "fzf"

# Media
brew "spicetify-cli"

# Fonts
cask "font-fira-code-nerd-font"
cask "font-hack-nerd-font"
cask "font-sf-pro"
cask "font-space-mono-nerd-font"

# Tools
cask "wezterm"
brew "wezterm"
brew "starship"
brew "btop"
brew "difftastic"
brew "gdu"
brew "lazydocker"
brew "bat"
brew "xh"
brew "posting"
EOF

# Download zimfw plugin manager if missing.
if [[ ! -e ${ZIM_HOME}/zimfw.zsh ]]; then
  curl -fsSL --create-dirs -o ${ZIM_HOME}/zimfw.zsh \
      https://github.com/zimfw/zimfw/releases/latest/download/zimfw.zsh
fi

# Install missing modules, and update ${ZIM_HOME}/init.zsh if missing or outdated.
if [[ ! ${ZIM_HOME}/init.zsh -nt ${ZDOTDIR:-${HOME}}/.zimrc ]]; then
  source ${ZIM_HOME}/zimfw.zsh init -q
fi
