## My ___dotfiles___


### We are using git bear repos to keep things clean.
___
Initial setup:
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

Cloning on another machine:
```bash
# Create your repo directory
mkdir -p $HOME/dotfiles

# Clone the repository
git clone --bare https://github.com/gkuba/dotfiles.git $HOME/dotfiles

# Checkout the files for the first time. Can't use config as the alias isn't currently set. NOTE: this will fail if you have any of the same files in your home dir such as a .bashrc.
/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME checkout

# Set the config options.
config config --local status.showUntrackedFiles no

```
---

The files below install the needed apps and clones the various repos needed for vim and the starship prompt.
- ```root.sh``` - This needs to be run with sudo as it installs the packages. Currently set up for Ubuntu.
- ```user.sh``` - Runs as the user.