# Dotfiles

This repository manages my home-directory configuration with a Git bare repository. The setup script installs shell tools, deploys dotfiles, syncs Zsh plugins, selects a hostname-specific Starship configuration, and can optionally update the managed hosts block.

Other Starship themes are available at https://github.com/gkuba/Starship-Configs.

## Quick setup

Paste this command into a Bash-compatible terminal to download and run the setup script:

```bash
bash <(curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/master/setup-dotfiles.sh)
```

If your current shell is fish or another shell that does not support Bash process substitution, start Bash first, then paste the command.

The wizard installs the shell tools, updates the bare dotfiles repository, syncs Zsh plugins, and selects the Starship configuration for the current hostname. It can also update the managed hosts block.

Package installation supports Arch-family systems through `pacman` and Debian/Ubuntu-family systems through `apt`; on apt systems, the script installs Nala first and uses it for the shell-tool package batch. The packages are Zsh, Starship, fzf, eza, Fastfetch, Git, curl, 7zip, unzip, and iproute2. The wizard asks whether to set Zsh as the login shell, defaulting to Yes; log out and back in for that change to take effect.

## Run one action

Run as your normal user. Each named action affects only the selected component:

```bash
bash setup-dotfiles.sh installShellPackages
bash setup-dotfiles.sh configureLoginShell
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

The wizard installs Starship with the other shell tools. The standalone `setupStarship` action also installs Starship if missing, then selects the host config: pixel uses pixel-starship.toml, matching Pi hosts use pi-starship.toml, and other hosts use starship.toml. Existing standalone config files are backed up under ~/.dotfiles-backup before replacement.

## Optional integrations

The hosts action backs up /etc/hosts and replaces only the managed block, preserving other entries and avoiding duplicate appended blocks.

Wallpaper and cursor installation is handled by the Arch post-install script, where it can be skipped on headless systems.

