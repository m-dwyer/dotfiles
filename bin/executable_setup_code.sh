#!/usr/bin/env zsh

alias code="code-insiders"

THEME_FILE="catppuccin-vsc-3.16.0.vsix"
THEME_VSIX="https://github.com/catppuccin/vscode/releases/download/catppuccin-vsc-v3.16.0/${THEME_FILE}"
curl -L  "${THEME_VSIX}" -o "/tmp/${THEME_FILE}"

code --install-extension "/tmp/${THEME_FILE}"

#rm "/tmp/${THEME_FILE}"