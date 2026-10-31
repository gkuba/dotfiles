# Dotfiles

This repository manages my home-directory configuration with a Git bare repository. The setup script installs shell tools, deploys the dotfiles (including the Starship configuration), syncs Zsh plugins, applies Fastfetch preferences, and can set Zsh as the login shell and update the managed hosts block.

## Quick setup

Paste this command into a Bash-compatible terminal to download and run the setup script:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/gkuba/dotfiles/master/setup-dotfiles.sh)
```

If your current shell is fish or another shell that does not support Bash process substitution, start Bash first, then paste the command. Run it as your normal user in a terminal of at least 80×24; it asks for your sudo password only after you confirm the plan.

To see everything it would do without changing anything, add `--dry-run`:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/gkuba/dotfiles/master/setup-dotfiles.sh) --dry-run
```

## The wizard

The script is a full-screen wizard built on [InstallScriptTemplate](https://github.com/gkuba/InstallScriptTemplate):

1. **Packages:** Zsh, Starship, fzf, eza, Fastfetch and Neovim; Git, curl, 7zip, unzip, iproute2 and the Fira Code font.
2. **Dotfiles:** the bare repository, Zsh plugins, backing up conflicting files, and standalone app configs.
3. **System and Fastfetch:** a full system update, Zsh as the login shell, the hosts block, and the Fastfetch image choices.
4. **Review selections:** every item with its status, where single items can be switched on or off.
5. **Review the plan:** what will run. Anything that would make the run fail is shown as a blocker, and the run cannot start until it is fixed.
6. **Authenticate**, then each step runs with its output on screen, followed by a summary and the full log.

Keys: ↑↓ move, Space toggles, Enter goes on, B goes back, Esc quits. On the install screen, Ctrl+C stops after the current step.

The defaults match a plain run: every package, the bare repository, Zsh plugins and the Zsh login shell are selected; the hosts block and the system update are not.

## Command-line options

Selection options choose exactly what runs and open the wizard at the review screen. Nothing runs until you confirm the plan and enter your password.

```text
-p, --packages     Shell tools, utilities, and the Fira Code font
-d, --dotfiles     Bare dotfiles repo (~/dotfiles) and Zsh plugins
-s, --system       Zsh as the login shell and the managed /etc/hosts block
-u, --update       Full system update before packages are installed
-A, --all          -p, -d and -s (add -u for a system update)
-n, --dry-run      Show every command that would change the system, change nothing
-h, --help         Show the help
```

Short options can be combined, for example `setup-dotfiles.sh -dn` to preview a dotfiles update.

## Packages

Package installation supports Arch-family systems through `pacman` and Debian/Ubuntu-family systems through `apt`. A tool that is already on your PATH counts as installed, even if it came from outside the package manager, so no second copy is added.

When anything needs installing on Arch, the script runs one `pacman -Syu --needed` transaction: it syncs the package databases, upgrades the system and installs the new packages together. Syncing without upgrading would be a partial upgrade, which Arch does not support. When everything is already installed, nothing is synced or upgraded.

On apt systems the script runs `apt-get update`, installs Nala first if needed, and uses it to install the packages. Packages that the enabled repositories do not provide are shown as a blocker on the plan screen. The complete package set requires Debian 13 (Trixie) or newer, or Ubuntu 25.10 or newer; older releases may not provide Starship, eza, or Fastfetch.

Fira Code is `ttf-fira-code` on Arch and `fonts-firacode` on Debian/Ubuntu. After setting Zsh as the login shell, log out and back in for the change to take effect.

## Bare repository

The bare Git repository lives at ~/dotfiles and uses your home directory as its work tree. Manage it with the `dotgit` function from `.shell_functions`:

    dotgit() { /usr/bin/git --git-dir="$HOME/dotfiles/" --work-tree="$HOME" "$@"; }

On a machine without ~/dotfiles, the script clones the repository over HTTPS, so no SSH key is needed yet. It then sets the same config this setup uses: origin switched to `git@github.com:gkuba/dotfiles.git` for updates and pushes, untracked files hidden (`status.showUntrackedFiles no`), and an upstream for `dotgit pull`. Before the first checkout it finds existing files that the checkout would overwrite. They are listed on the plan screen, and with **Back up conflicts** selected they are moved into a timestamped folder under ~/.dotfiles-backup first.

On an existing repository the script only fetches the current branch and fast-forwards it, like `dotgit pull --ff-only`. It writes no Git config and adds no remote-tracking refs. It stops with nothing changed when:

- tracked files have local edits (check them with `dotgit status` and `dotgit diff`),
- the update would overwrite untracked files and **Back up conflicts** is not selected,
- the branch has local commits that are not on origin, so it cannot fast-forward.

The origin URL is left as it is. Git runs without prompts during the install steps, so have your SSH key loaded in an agent. If fetching from the SSH origin fails anyway (for example, on a box where the key is not set up yet), the update fetches once over HTTPS instead, without changing origin. Pushing still needs the SSH key.

## Starship configuration

The Starship config is tracked in this repository as `.config/starship.toml` and is deployed with the other dotfiles. On machines without the bare repository, **App configs only** downloads it along with the Neovim and Fastfetch configs; an existing file is backed up under ~/.dotfiles-backup before it is replaced, and left alone when it is already current.

## Fastfetch preferences

Two choices on the System and Fastfetch page control Fastfetch:

- **Fastfetch images:** keep the custom logo images. Switching it off removes them from your home directory; they stay in the repository.
- **Fastfetch ASCII:** use Fastfetch's built-in system logo instead of an image, with no top padding.

On Hyprland, `.zshrc` runs Fastfetch with `~/.config/fastfetch/hyprland.jsonc` instead (a WM row and no logo top padding); keep it in step with `config.jsonc` when the layout changes. If you remove the bundled images but keep the image logo, place your own PNG files in `~/.config/fastfetch/images`.

The choices are saved in `~/.config/dotfiles-setup/fastfetch.conf` and become the defaults next time. The edited files are hidden from `dotgit status` with Git's skip-worktree flag. Before a dotfiles update they are restored so Git can update them, and the saved preferences are applied again afterwards.

## Standalone app configs

**App configs only** downloads just the Neovim, Fastfetch and Starship configs, for machines that do not use the bare repository. It cannot be combined with the bare repository, since it would overwrite files the repository tracks. Existing files are backed up under ~/.dotfiles-backup first.

## Hosts block

The hosts step downloads the list from the Gist, backs up /etc/hosts to /etc/hosts.bak.&lt;timestamp&gt;, and replaces only the block between the `# >>> gkuba custom hosts >>>` markers, preserving every other entry. It does nothing when the block is already current, and it refuses to run if the markers are nested, repeated or out of order.

## Logs

Every run writes a log to /tmp (the path is shown on the last screen; Ctrl+D opens it). The sudo password is never logged.

Wallpaper and cursor installation is handled by the Arch post-install script, where it can be skipped on headless systems.
