# Dotfiles

This repository manages my home-directory configuration with a Git bare repository. The setup script deploys dotfiles, syncs Zsh plugins, selects a hostname-specific Starship configuration, and can optionally update the managed hosts block.

Other Starship themes are available at https://github.com/gkuba/Starship-Configs.

## Quick setup

Paste this command into a Bash-compatible terminal to download and run the setup script:

```bash
bash <(curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/master/setup-dotfiles.sh)
```

If your current shell is fish or another shell that does not support Bash process substitution, start Bash first, then paste the command.

The wizard updates the bare dotfiles repository, syncs Zsh plugins, and selects the Starship configuration for the current hostname. It can also update the managed hosts block.

This script manages configs and Git checkouts. Install packages and set the Zsh login shell with the Arch post-install script.

## Run one action

Run as your normal user. Each named action affects only the selected component:

```bash
bash setup-dotfiles.sh setupDotfiles
bash setup-dotfiles.sh setupZsh
bash setup-dotfiles.sh setupNvim
bash setup-dotfiles.sh setupFastfetch
bash setup-dotfiles.sh setupStarship
bash setup-dotfiles.sh updateHostsFile
```

Use --help to list actions.

## Bare repository

The bare Git repository lives at ~/dotfiles and uses your home directory as its work tree. The script fetches updates and only fast-forwards a clean checkout. If tracked files have local edits, it stops before fetching and prints commands to inspect them.

Before the first checkout, the script lists existing paths that would conflict and asks whether to move them into a timestamped folder under ~/.dotfiles-backup. Declining leaves those paths untouched. If checkout still fails after backup, it stops and shows how to inspect status.

    /usr/bin/git --git-dir="$HOME/dotfiles" --work-tree="$HOME" status --short
    /usr/bin/git --git-dir="$HOME/dotfiles" --work-tree="$HOME" diff

A convenient alias is:

    alias dotgit='/usr/bin/git --git-dir="$HOME/dotfiles/" --work-tree="$HOME"'

## Starship configuration

setupStarship retains hostname-based selection: pixel uses pixel-starship.toml, matching Pi hosts use pi-starship.toml, and other hosts use starship.toml. Existing standalone config files are backed up under ~/.dotfiles-backup before replacement. Starship itself is installed by the Arch post-install script.

## Optional integrations

The hosts action backs up /etc/hosts and replaces only the managed block, preserving other entries and avoiding duplicate appended blocks.

Wallpaper and cursor installation is handled by the Arch post-install script, where it can be skipped on headless systems.

