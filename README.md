# dotfiles

A repository containing dotfiles for my Mac setup.

## Overview

I use [AeroSpace](https://github.com/nikitabobko/AeroSpace) to manage several workspaces, with mostly a vanilla configuration taken from the guide [here](https://nikitabobko.github.io/AeroSpace/guide). Each workspace is a category of application, with the following:

1. Web - apps associated with browsing (e.g. Chromium)
2. Code - apps associated with coding (e.g. VSCode)
3. Music - apps associated with music (e.g. Spotify)
4. Files - apps associated with file management (e.g. Finder)
5. Terminal - apps associated with the command line (e.g. iTerm2)
6. Productivity - apps associated with organisational things (e.g. Obsidian)
7. Miscellaneous - apps that aren't otherwise captured end up here

I use the `on-window-detected` for certain apps which results in them being moved to the correct workspace to better organise my desktop.

I use [SketchyBar](https://github.com/FelixKratz/SketchyBar) along with SketchyLua instead of the vanilla Mac menubar. This integrates well with AeroSpace, and will show my workspace with number and name, along with highlighting my current workspace.

For general purpose utilities and key bindings, I use [HammerSpoon](https://www.hammerspoon.org/).

## Usage

1. Install Homebrew with `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"`
1. `brew install chezmoi`
2. `git clone git@github.com:m-dwyer/dotfiles.git ~/.local/share/chezmoi`
3. `chezmoi apply`

This will apply the dotfiles while installing required Homebrew packages.