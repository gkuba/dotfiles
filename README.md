# My ___dotfiles___

## Installation Info

Just copy and paste in your terminal.

```bash
curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/master/dotfile_user.sh |bash
```

___

## Manual Installation and First Time Setup

If you would like to set this up for yourself follow the __First Time Setup__ or if you would like to manually set this up to get a better understanding follow the __Manual Installaion__ section.

### First Time Setup

We are using git bear repos to keep things clean

First time setup: - Only used once.

```bash
#Create your repo directory
git init --bare $HOME/dotfiles

# Set up the alias for working with your files in your .bashrc or .zshrc
alias config='/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME'

# Restart your terminal session or rerun your shell of choice.
bash

# Set the config options.
config config --local status.showUntrackedFiles no
```

Basic usage example:

```bash
config add /path/to/file
config commit -m "A short message"
config push
```

___

### Manual Installation

Cloning on another machine: - Every other time you setup.

```bash
# Create your repo directory
mkdir -p $HOME/dotfiles

# Clone the repository
git clone --bare https://github.com/gkuba/dotfiles.git $HOME/dotfiles

# Checkout the files for the first time. Can't use config as the alias isn't currently set. 
# NOTE: this will fail if you have any of the same files in your home dir such as a .bashrc.
/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME checkout

# Set the config options.
config config --local status.showUntrackedFiles no

```

Run ```./dotfile_user.sh``` as your user to install the needed apps and clone the various repos needed for vim and the Starship prompt.

__NOTE:__ You may have to make ```dotfile_user.sh``` executable which can be done with ```chmod +x dotfile_user.sh```
