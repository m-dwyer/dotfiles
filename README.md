# dotfiles

A repository containing dotfiles for my Arch Linux setup.

Includes configuration for window management, themes and commonly used apps.

## Usage
1. Install GNU stow:  
`~$ sudo pacman -S stow`
2. Clone this repository into your home directory and cd into it:  
`~$ git clone git@github.com:m-dwyer/dotfiles.git`  
`~$ cd dotfiles`
3. Run stow <app> to create the relevant symlinks for each application. E.g. for compton:  
`dotfiles$ stow compton`
