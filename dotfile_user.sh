#! /bin/bash

### TO DO: ###
# See about adding a starship theme set of options with examples.

## Sets up the git config alias for use before dot files are pulled down.
function dotgit {
  /usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME $@
}

## Gets starship config based on hostname. If it doesn't match a host below it will grab the default.
function getConfig {
  if [ -z "$@" ]
  then
    curl -sS https://raw.githubusercontent.com/gkuba/Starship-Configs/main/starship.toml -o .config/starship.toml
  else
    curl -sS https://raw.githubusercontent.com/gkuba/Starship-Configs/main/$@-starship.toml -o .config/starship.toml
  fi
}

# Gets the zsh plugins needed for fish like terminal features.
function getZshPlugins {
  if ! [ -e $HOME/.zsh ]; then
  mkdir -p $HOME/.zsh
  fi
  git clone https://github.com/zsh-users/zsh-autosuggestions ~/.zsh/zsh-autosuggestions
  git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.zsh/zsh-syntax-highlighting
}

## Defining colors for our text output
green="\033[0;38;5;2m"
white="\033[0;38;5;7m"
yellow="\033[0;38;5;3m"

if ! [ -e $HOME/dotfiles ]; then
  mkdir -p $HOME/dotfiles
  git clone --bare https://github.com/gkuba/dotfiles.git $HOME/dotfiles
fi

dotgit config --local status.showUntrackedFiles no

## Variables
DOTFILES=(".bashrc" ".shell_aliases" ".shell_colors" ".shell_environment" ".shell_functions" ".zshrc")
NVIMDOTFILES=("init.lua")
EXISTING_DOTFILES=()
EXISTING_NVIMDOTFILES=()

## Checking if the specified dotfiles exist if so making a backup directory and moving them there.
for file in ${DOTFILES[@]}; do
  if [ -e $HOME/$file ]; then
    EXISTING_DOTFILES+=( $file )
  fi
done

if ! [ ${#EXISTING_DOTFILES[@]} -eq 0 ]; then
    echo -e "\n$yellow  [INFO]$white Removing dotfiles $green\"${EXISTING_DOTFILES[*]}\"$white found in home directory."
  for file in ${EXISTING_DOTFILES[@]}; do
    rm -f $HOME/$file
  done
fi

## Checking if the specified vim dotfiles exist if so adding them to the backup directory.
for file in ${NVIMDOTFILES[@]}; do
  if [ -e $HOME/.config/nvim/$file ]; then
    EXISTING_VIMDOTFILES+=( $file )
  fi
done

if ! [ ${#EXISTING_NVIMDOTFILES[@]} -eq 0 ]; then
    echo -e "\n$yellow  [INFO]$white Removing nvim dotfiles $green\"${EXISTING_NVIMDOTFILES[*]}\"$white found in home directory."
  for file in ${EXISTING_NVIMDOTFILES[@]}; do
    rm -rf $HOME/.config/nvim/$file
  done
fi

# SETUP NVIM
if ! [ -e $HOME/.config/nvim ]; then
  mkdir -p $HOME/.config/nvim
fi

dotgit checkout -f

getZshPlugins

# Install starship
sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y

# If hostname matches one below automatically grab starship theme and replace default.
if [ $HOSTNAME = "pixel" ]; then
  getConfig pixel
elif [[ $HOSTNAME = *"pi"* ]] || [[ $HOSTNAME = "pixelshed" ]]; then
  getConfig pi
else
  getConfig 
fi
