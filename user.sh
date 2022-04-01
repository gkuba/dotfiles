#! /bin/bash

### TO DO: ###
# Get this all converted and put in a ansible playbook.

## Sets up the git config alias for use before dot files are pulled down.
function config {
   /usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME $@
}

## Defining colors for our text output
green="\033[0;38;5;2m"
white="\033[0;38;5;7m"
yellow="\033[0;38;5;3m"

mkdir -p $HOME/dotfiles
git clone --bare https://github.com/gkuba/dotfiles.git $HOME/dotfiles
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
  for file in ${EXISTING_DOTFILES[@]}; do
    rmdir -f $HOME/.vim/bundle/$file
  done
fi

config checkout -f

# VIM SETUP
mkdir -p ~/.vim/autoload ~/.vim/bundle
curl -LSso  ~/.vim/autoload/pathogen.vim https://raw.githubusercontent.com/tpope/vim-pathogen/master/autoload/pathogen.vim
git clone https://github.com/bling/vim-airline.git ~/.vim/bundle/vim-airline
git clone https://github.com/tpope/vim-fugitive.git ~/.vim/bundle/vim-fugitive
git clone https://github.com/vim-airline/vim-airline-themes ~/.vim/bundle/vim-airline-themes
git clone https://github.com/gosukiwi/vim-atom-dark.git ~/.vim/bundle/vim-atom-dark.vim
git clone https://github.com/trusktr/seti.vim ~/.vim/bundle/seti.vim
fc-cache -vf ~/.fonts/
mkdir -p $HOME/.vim/colors
cp $HOME/.vim/bundle/vim-atom-dark.vim/colors/atom-dark-256.vim $HOME/.vim/colors/
cp $HOME/.vim/bundle/seti.vim/colors/seti.vim $HOME/.vim/colors/
