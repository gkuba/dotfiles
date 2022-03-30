## My ___dotfiles___


### We are using git bear repos to keep things clean.
___
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

Cloning on another machine: - Every other time you setup.
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
Or you can run the following commands:
```bash
curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/master/root.sh |bash
curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/master/user.sh |bash
```

---

The files below install the needed apps and clones the various repos needed for vim and the starship prompt.
- ```root.sh``` - This needs to be run with sudo as it installs the packages. Currently set up for Ubuntu.
- ```user.sh``` - Runs as the user.
