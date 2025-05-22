#!/usr/bin/env zsh

alias code="code-insiders"

# Check if the 'extensions' file exists
if [[ ! -f "extensions" ]]; then
  echo "'extensions' file not found."
  exit 1
fi

# Read the extensions from the file and install each one
while IFS= read -r extension; do
  if [[ -n "$extension" ]]; then
    echo "Installing extension: $extension"
    code --install-extension $extension --force
  fi
done < extensions

echo "All extensions have been installed."
