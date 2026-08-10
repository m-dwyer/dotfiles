#!/usr/bin/env bash

# Install required packages.
# No --no-lock: the flag was removed in Homebrew 6 and made this fail silently,
# because without `|| exit 1` the script still exited 0 and chezmoi recorded the
# run_once script as done while installing nothing.
brew bundle --file=/dev/stdin <<EOF || exit 1

tap "homebrew/bundle"
tap "homebrew/services"

# Util
brew "chezmoi"
# Bootstraps every language runtime — must come from brew, not from itself.
# Deliberately no "node" here: node/pnpm are owned by mise (~/.config/mise/config.toml).
brew "mise"
brew "direnv"
brew "eza"
brew "gh"

# Desktop
tap "felixkratz/formulae"
tap "nikitabobko/tap"
tap "koekeishiya/formulae"
# Fully qualified: yabai also exists in asmvik/formulae, which brew rejects as ambiguous.
brew "koekeishiya/formulae/yabai"
brew "lua"
brew "felixkratz/formulae/borders"
brew "felixkratz/formulae/sketchybar"
cask "aerospace"
cask "hammerspoon"
cask "keyclu"

brew "nowplaying-cli"
brew "switchaudio-osx"

# File Management
brew "yazi"
brew "mediainfo"
brew "zoxide"
brew "ripgrep"
brew "fzf"

# Fonts
cask "font-fira-code-nerd-font"
cask "font-hack-nerd-font"
cask "font-sf-pro"
cask "font-space-mono-nerd-font"

# Tools
# Cask only: the wezterm formula was removed from homebrew-core, and the cask
# already provides the wezterm/wezterm-gui/wezterm-mux-server symlinks.
cask "wezterm"
brew "starship"
brew "btop"
brew "neovim"
brew "difftastic"
brew "gdu"
brew "lazydocker"
brew "devcontainer"
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
