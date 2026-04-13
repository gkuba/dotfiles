# My __dotfiles__

__NOTE:__ You can get my other themes/styles for the Starship prompt here: [gkuba/Starship-Config][gkuba/Starship-Config]

[gkuba/Starship-Config]: https://github.com/gkuba/Starship-Configs

## Installation Info

Just copy and paste this command into your terminal and it will pull down my dotfiles and VIM configs as well as the Fira Code fonts for you.

Note: If your default shell is fish (or any non-bash shell), run the `bash` command first:
```bash
bash <(curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/master/setup-dotfiles.sh)
```

If you would like to set this up for yourself follow the __First Time Setup__ or if you would like to manually set this up to get a better understanding follow the __Manual Installation__ section.

___

## Manual Installation and First-Time Setup

If you are setting this up for yourself you may want to just download or fork my repository and update line 22 of the script to your repository.

```bash
git clone --bare https://github.com/gkuba/dotfiles.git $HOME/dotfiles
```

### First Time Setup

We are using git bare repository to keep things clean

First Time Setup: - Only used once.

```bash
#Create your repo directory
git init --bare $HOME/dotfiles

# Set up the alias for working with your files in your .bashrc or .zshrc
alias dotgit='/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME'

# Restart your terminal session or rerun your shell of choice.
bash

# Set the config options.
dotgit config --local status.showUntrackedFiles no
```

Basic usage example:

```bash
dotgit add /path/to/file
dotgit commit -m "A short message"
dotgit push
```

___

### Manual Installation

Cloning on another machine: - Every other time you set up.
__NOTE:__ Don't forget to change the repository below to your own.

```bash
# Create your repo directory
mkdir -p $HOME/dotfiles

# Clone the repository
git clone --bare https://github.com/gkuba/dotfiles.git $HOME/dotfiles

# Checkout the files for the first time. Can't use config as the alias isn't currently set. 
# NOTE: this will fail if you have any of the same files in your home dir such as a .bashrc.
/usr/bin/git --git-dir=$HOME/dotfiles/ --work-tree=$HOME checkout

# Restart your terminal session or rerun your shell of choice.
bash

# Set the config options.
dotgit config --local status.showUntrackedFiles no

```

Run ```./dotfile_user.sh``` as your user to install the needed apps and clone the various repositories needed for vim and the Starship prompt.

__NOTE:__ You may have to make ```dotfile_user.sh``` executable which can be done with this:
```chmod +x dotfile_user.sh```

