#! /bin/bash

### TO DO: ###
# See about adding a starship theme set of options with examples.

## Sets up the git config alias for use before dot files are pulled down.
function config {
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

## Defining colors for our text output
green="\033[0;38;5;2m"
white="\033[0;38;5;7m"
yellow="\033[0;38;5;3m"

if ! [ -e $HOME/dotfiles ]; then
  mkdir -p $HOME/dotfiles
  git clone --bare https://github.com/gkuba/dotfiles.git $HOME/dotfiles
fi

config config --local status.showUntrackedFiles no

## Variables
DOTFILES=(".bashrc" ".aliases" ".colors" ".environment" ".functions" ".zshrc" ".vimrc")
VIMDOTFILES=("vim-airline" "vim-fugitive" "vim-airline-themes" "vim-atom-dark.vim" "seti.vim")
EXISTING_DOTFILES=()
EXISTING_VIMDOTFILES=()

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
for file in ${VIMDOTFILES[@]}; do
  if [ -e $HOME/.vim/bundle/$file ]; then
    EXISTING_VIMDOTFILES+=( $file )
  fi
done

if ! [ ${#EXISTING_VIMDOTFILES[@]} -eq 0 ]; then
    echo -e "\n$yellow  [INFO]$white Removing vim dotfiles $green\"${EXISTING_VIMDOTFILES[*]}\"$white found in home directory."
  for file in ${EXISTING_VIMDOTFILES[@]}; do
    rm -rf $HOME/.vim/bundle/$file
  done
fi

config checkout -f

# VIM SETUP
mkdir -p $HOME/.vim/autoload $HOME/.vim/bundle $HOME/.vim/pack/themes/start
curl -LSso  $HOME/.vim/autoload/pathogen.vim https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim
git clone https://github.com/bling/vim-airline.git $HOME/.vim/bundle/vim-airline
git clone https://github.com/tpope/vim-fugitive.git $HOME/.vim/bundle/vim-fugitive
git clone https://github.com/vim-airline/vim-airline-themes $HOME/.vim/bundle/vim-airline-themes
git clone https://github.com/dracula/vim.git $HOME/.vim/pack/themes/start/dracula
fc-cache -vf $HOME/.fonts/

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