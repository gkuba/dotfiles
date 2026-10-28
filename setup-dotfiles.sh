#!/usr/bin/env bash
# =============================================================================
# Dotfiles Setup - interactive bare-repository configuration installer
# =============================================================================
set -Eeuo pipefail

# Colors
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
BLUE=$'\033[0;34m'
MAGENTA=$'\033[0;35m'
CYAN=$'\033[0;36m'
WHITE=$'\033[0;37m'
DIM=$'\033[2m'
BOLD=$'\033[1m'
RESET=$'\033[0m'

# Configuration
DOTFILES_REPO='https://github.com/gkuba/dotfiles.git'
DOTFILES_DIR="$HOME/dotfiles"
DOTFILES_BACKUP_DIR="$HOME/.dotfiles-backup"
STARSHIP_CONFIG_REPO='https://raw.githubusercontent.com/gkuba/Starship-Configs/main'
HOSTS_GIST_URL='https://gist.githubusercontent.com/gkuba/328f47706216baaf6cdc6c5519bf84c2/raw/73b9f6d7bd6cff4cb44d0da872747a1cbce66e0d/gistfile1.txt'
HOSTS_BLOCK_START='# >>> gkuba custom hosts >>>'
HOSTS_BLOCK_END='# <<< gkuba custom hosts <<<'
ZSH_PLUGIN_REPOS='zsh-users/zsh-autosuggestions
zsh-users/zsh-syntax-highlighting
zsh-users/zsh-history-substring-search'
SHELL_PACKAGES=(zsh starship fzf eza fastfetch git curl 7zip unzip iproute2 neovim)

CURRENT_USER=''
CURRENT_HOST=''
CURRENT_OS=''
TEMP_DIR=''
COMPLETED='|'
RUN_HOSTS=false
RUN_LOGIN_SHELL=false
RUN_FASTFETCH_KEEP_IMAGES=true
RUN_FASTFETCH_ASCII=false
FASTFETCH_ANSWERS_GATHERED=false
TTY=false
SINGLE_ACTION=false
SINGLE_LABEL=''
SCREEN_OUTPUT_TOP=1
SCREEN_FINAL_STEP_ROW=1
SCREEN_ACTIVE_STEP_ROW=1

show_help() {
    printf '%sUsage:%s setup-dotfiles.sh [action|--help]\n\n' "$CYAN" "$RESET"
    printf '%sActions:%s\n' "$YELLOW" "$RESET"
    printf '  installShellPackages Install shell tools with pacman or apt\n'
    printf '  configureLoginShell  Set Zsh as the login shell\n'
    printf '  setupDotfiles       Safely clone or update and check out the bare dotfiles repo\n'
    printf '  setupZsh            Clone or fast-forward configured Zsh plugins\n'
    printf '  setupNvim           Download standalone Neovim config with a backup\n'
    printf '  setupFastfetch      Download standalone Fastfetch config with a backup\n'
    printf '  setupStarship       Install Starship and configure this host'\''s prompt\n'
    printf '  updateHostsFile     Replace the managed hosts block from the configured Gist\n'
    printf '\nNo action runs the interactive wizard. One named action runs only that action.\n'
    printf 'This script installs shell tools when needed, manages configs, and sets Zsh as the login shell.\n'
}

info()    { printf '%s[INFO]%s %s\n' "$BLUE" "$RESET" "$*"; }
info_identity() { printf '%s[INFO]%s %s%s:%s %s\n' "$BLUE" "$RESET" "$CYAN" "$1" "$RESET" "$2"; }
success() { printf '%s[ OK ]%s %s\n' "$GREEN" "$RESET" "$*"; }
warn()    { printf '%s[WARN]%s %s\n' "$YELLOW" "$RESET" "$*" >&2; }
error()   { printf '%s[ERR ]%s %s\n' "$RED" "$RESET" "$*" >&2; }
is_tty()  { [[ -t 0 && -t 1 && -n "${TERM:-}" && "${TERM:-dumb}" != dumb ]]; }

init_terminal() {
    if is_tty; then TTY=true; else
        RED=''; GREEN=''; YELLOW=''; BLUE=''; MAGENTA=''; CYAN=''; WHITE=''; DIM=''; BOLD=''; RESET=''
    fi
}

draw_screen() {
    local active="$1" item mark color visible_steps=0
    SCREEN_ACTIVE_STEP_ROW=0
    if [[ "$TTY" != true ]]; then
        printf 'Dotfiles Setup — %s\n' "$active"
        return 0
    fi
    printf '\033[H\033[2J'
    printf '%s%s╭──────────────────────────────────────────────╮%s\n' "$MAGENTA" "$BOLD" "$RESET"
    printf '%s%s│               Dotfiles Setup                 │%s\n' "$MAGENTA" "$BOLD" "$RESET"
    printf '%s%s╰──────────────────────────────────────────────╯%s\n' "$MAGENTA" "$BOLD" "$RESET"
    for item in 'Gathering Information' 'Installing Shell Packages' 'Configuring Login Shell' 'Updating Dotfiles' 'Syncing Zsh Plugins' 'Configuring Neovim' 'Configuring Fastfetch' 'Configuring Starship' 'Updating Hosts File' 'Finalizing'; do
        if [[ "$SINGLE_ACTION" == true ]]; then
            [[ "$item" == "$SINGLE_LABEL" || "$item" == 'Finalizing' ]] || continue
        else
            [[ "$item" == 'Configuring Neovim' ]] && continue
            [[ "$item" == 'Updating Hosts File' && "$RUN_HOSTS" != true ]] && continue
            [[ "$item" == 'Configuring Login Shell' && "$RUN_LOGIN_SHELL" != true ]] && continue
        fi
        mark='○'; color="$DIM"
        if [[ "$active" == "$item" ]]; then mark='●'; color="$CYAN$BOLD"
        else case "$COMPLETED" in *"|$item|"*) mark='✓'; color="$GREEN" ;; esac
        fi
        printf '  %s%s %s%s\n' "$color" "$mark" "$item" "$RESET"
        visible_steps=$((visible_steps + 1))
        [[ "$active" == "$item" ]] && SCREEN_ACTIVE_STEP_ROW=$((3 + visible_steps))
    done
    printf '\n'
    SCREEN_OUTPUT_TOP=$((5 + visible_steps))
    SCREEN_FINAL_STEP_ROW=$((3 + visible_steps))
}

mark_final_step_complete() {
    [[ "$TTY" == true ]] || return 0
    printf '\033[%d;1H\033[2K  %s✓ Finalizing%s\033[%d;1H' \
        "$SCREEN_FINAL_STEP_ROW" "$GREEN" "$RESET" "$SCREEN_OUTPUT_TOP"
}

mark_active_step_complete() {
    local label="$1"
    [[ "$TTY" == true && "$SCREEN_ACTIVE_STEP_ROW" -gt 0 ]] || return 0
    printf '\033[%d;1H\033[2K  %s✓ %s%s\033[%d;1H' \
        "$SCREEN_ACTIVE_STEP_ROW" "$GREEN" "$label" "$RESET" "$SCREEN_OUTPUT_TOP"
}

panel() {
    local title="$1" line dash_count
    shift
    dash_count=$((50 - ${#title}))
    (( dash_count < 1 )) && dash_count=1
    printf '%s┌─ %s ' "$CYAN" "$title"
    printf '─%.0s' $(seq 1 "$dash_count")
    printf '┐%s\n' "$RESET"
    for line in "$@"; do printf '%s│%s %s\n' "$CYAN" "$RESET" "$line"; done
    printf '%s└─────────────────────────────────────────────────────┘%s\n' "$CYAN" "$RESET"
}

ask_yes_no() {
    local prompt="$1" default="$2" answer suffix='[y/N]'
    [[ "$default" == yes ]] && suffix='[Y/n]'
    while true; do
        read -r -p "$prompt $suffix " answer || return 1
        answer=$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')
        if [[ -z "$answer" ]]; then [[ "$default" == yes ]] && return 0 || return 1; fi
        case "$answer" in y|yes) return 0 ;; n|no) return 1 ;; *) warn 'Please answer y or n.' ;; esac
    done
}
confirm_plan() {
    local answer
    read -r -p 'Continue with this plan? [Y/n] ' answer || return 1
    answer=$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')
    [[ -z "$answer" || "$answer" == y || "$answer" == yes ]]
}
require_commands() {
    local name
    for name in "$@"; do command -v "$name" >/dev/null 2>&1 || { error "Required command missing: $name"; return 1; }; done
}
make_temp_dir() { [[ -n "$TEMP_DIR" ]] || TEMP_DIR=$(mktemp -d /tmp/dotfiles-setup.XXXXXXXX); }
cleanup_temp_dir() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then rm -rf -- "$TEMP_DIR"; fi
    return 0
}
trap cleanup_temp_dir EXIT
download_to() { curl --fail --location --silent --show-error "$1" --output "$2"; }

backup_existing_file() {
    local path="$1" relative backup_root
    [[ -e "$path" || -L "$path" ]] || return 0
    relative=$(realpath --relative-to="$HOME" "$path")
    backup_root="$DOTFILES_BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
    mkdir -p -- "$backup_root/$(dirname "$relative")"
    cp -a -- "$path" "$backup_root/$relative"
    info "Backed up $path to $backup_root/$relative"
}
dotgit() { /usr/bin/git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" "$@"; }

ensureDotfilesTracking() {
    local current_url branch
    current_url=$(dotgit remote get-url origin 2>/dev/null || true)
    if [[ -z "$current_url" ]]; then
        dotgit remote add origin "$DOTFILES_REPO"
    elif [[ "$current_url" != "$DOTFILES_REPO" ]]; then
        warn "origin is $current_url, expected $DOTFILES_REPO; leaving it unchanged."
    fi
    dotgit config --local remote.origin.fetch '+refs/heads/*:refs/remotes/origin/*'
    dotgit config --local status.showUntrackedFiles no
    dotgit fetch --prune origin
    branch=$(dotgit symbolic-ref --quiet --short HEAD) || { error 'The bare repository HEAD is not on a branch; stopped safely.'; return 1; }
    dotgit rev-parse --verify -q "origin/$branch" >/dev/null \
        || { error "origin/$branch not found; stopped safely."; return 1; }
    dotgit branch --set-upstream-to="origin/$branch" "$branch" >/dev/null
}

restoreFastfetchOverrides() {
    local entry status relative
    local -a paths=()
    [[ -d "$DOTFILES_DIR" && "$(dotgit rev-parse --is-bare-repository 2>/dev/null || true)" == true ]] || return 0
    while IFS= read -r -d '' entry; do
        status=${entry:0:1}; relative=${entry:2}
        [[ "$status" == S ]] || continue
        case "$relative" in
            .config/fastfetch/config.jsonc|.config/fastfetch/images/*) paths+=("$relative") ;;
        esac
    done < <(dotgit ls-files -v -z -- .config/fastfetch)
    ((${#paths[@]})) || return 0
    dotgit update-index --no-skip-worktree -- "${paths[@]}"
    dotgit checkout -- "${paths[@]}"
}

markFastfetchOverride() {
    local relative="$1"
    dotgit ls-files --error-unmatch -- "$relative" >/dev/null 2>&1 || return 0
    dotgit update-index --skip-worktree -- "$relative"
}

saveFastfetchAnswers() {
    local preferences="$HOME/.config/dotfiles-setup/fastfetch.conf"
    mkdir -p -- "$(dirname "$preferences")"
    umask 077
    {
        printf 'KEEP_IMAGES=%s\n' "$RUN_FASTFETCH_KEEP_IMAGES"
        printf 'USE_ASCII=%s\n' "$RUN_FASTFETCH_ASCII"
    } > "$preferences"
    chmod 600 "$preferences"
}

applyFastfetchAnswers() {
    local config="$HOME/.config/fastfetch/config.jsonc" relative
    local -a images=()
    [[ -f "$config" ]] || { warn 'Fastfetch config was not found; leaving its settings unchanged.'; return 0; }
    require_commands git sed || return 1
    if [[ "$RUN_FASTFETCH_KEEP_IMAGES" != true ]]; then
        while IFS= read -r -d '' relative; do images+=("$relative"); done < <(dotgit ls-files -z -- .config/fastfetch/images 2>/dev/null || true)
        if ((${#images[@]})); then
            for relative in "${images[@]}"; do markFastfetchOverride "$relative"; done
            for relative in "${images[@]}"; do rm -f -- "$HOME/$relative"; done
            find "$HOME/.config/fastfetch/images" -depth -type d -empty -delete 2>/dev/null || true
        fi
    fi
    if [[ "$RUN_FASTFETCH_ASCII" == true ]]; then
        if ! sed -i \
            -e 's/"type": "kitty-direct"/"type": "builtin"/' \
            -e 's|"source": "~/.config/fastfetch/images/\*\.png"|"source": ""|' \
            -e '/"padding": {/,/^[[:space:]]*}[,]*/ s/"top": [0-9][0-9]*/"top": 0/' \
            "$config"; then
            error 'Could not update Fastfetch to use the built-in system logo.'
            return 1
        fi
        markFastfetchOverride '.config/fastfetch/config.jsonc'
    fi
    saveFastfetchAnswers
    success 'Fastfetch preferences applied.'
}

gatherFastfetchAnswers() {
    if [[ "$FASTFETCH_ANSWERS_GATHERED" != true ]]; then
        if ask_yes_no 'Keep custom Fastfetch images?' yes; then
            RUN_FASTFETCH_KEEP_IMAGES=true
            RUN_FASTFETCH_ASCII=false
        else
            RUN_FASTFETCH_KEEP_IMAGES=false
            if ask_yes_no 'Update Fastfetch to use the default ASCII system image?' no; then RUN_FASTFETCH_ASCII=true; else RUN_FASTFETCH_ASCII=false; fi
        fi
        FASTFETCH_ANSWERS_GATHERED=true
    fi
}

applySavedFastfetchPreferences() {
    local preferences="$HOME/.config/dotfiles-setup/fastfetch.conf" key value
    [[ "$FASTFETCH_ANSWERS_GATHERED" != true && -r "$preferences" ]] || return 0
    RUN_FASTFETCH_KEEP_IMAGES=true
    RUN_FASTFETCH_ASCII=false
    while IFS='=' read -r key value; do
        case "$key:$value" in
            KEEP_IMAGES:true|KEEP_IMAGES:false) RUN_FASTFETCH_KEEP_IMAGES="$value" ;;
            USE_ASCII:true|USE_ASCII:false) RUN_FASTFETCH_ASCII="$value" ;;
        esac
    done < "$preferences"
    FASTFETCH_ANSWERS_GATHERED=true
    applyFastfetchAnswers
}

run_in_output_region() {
    local action="$1" rows
    shift
    if [[ "$TTY" != true ]]; then "$action" "$@"; return $?; fi
    rows=$(tput lines 2>/dev/null) || rows=24
    if (( SCREEN_OUTPUT_TOP >= rows )); then "$action" "$@"; return $?; fi

    printf '\033[%d;%dr\033[%d;1H' "$SCREEN_OUTPUT_TOP" "$rows" "$SCREEN_OUTPUT_TOP"
    "$action" "$@"
    printf '\033[r'
}

restore_output_region_on_error() {
    local status=$?
    if [[ "$TTY" == true ]]; then printf '\033[r\033[?25h\n'; fi
    exit "$status"
}
trap restore_output_region_on_error ERR

collect_conflicts() {
    local ref="$1" relative target prefix
    : > "$TEMP_DIR/conflicts.raw"
    while IFS= read -r -d '' relative; do
        dotgit ls-files --error-unmatch -- "$relative" >/dev/null 2>&1 && continue
        target="$HOME/$relative"
        if [[ -e "$target" || -L "$target" ]]; then printf '%s\0' "$relative" >> "$TEMP_DIR/conflicts.raw"; continue; fi
        prefix="$relative"
        while [[ "$prefix" == */* ]]; do
            prefix="${prefix%/*}"
            target="$HOME/$prefix"
            if [[ -L "$target" || ( -e "$target" && ! -d "$target" ) ]]; then printf '%s\0' "$prefix" >> "$TEMP_DIR/conflicts.raw"; break; fi
        done
    done < <(dotgit ls-tree -r -z --name-only "$ref")
    sort -zu "$TEMP_DIR/conflicts.raw" -o "$TEMP_DIR/conflicts"
}
backup_conflicts() {
    local relative source backup_root answer
    [[ -s "$TEMP_DIR/conflicts" ]] || return 0
    printf '\n%sExisting paths conflict with the checkout:%s\n' "$YELLOW" "$RESET"
    while IFS= read -r -d '' relative; do printf '  • %s\n' "$relative"; done < "$TEMP_DIR/conflicts"
    printf 'They can be moved into %s with their directory structure.\n' "$DOTFILES_BACKUP_DIR"
    read -r -p 'Back up these paths and continue? [y/N] ' answer || return 1
    answer=$(printf '%s' "$answer" | tr '[:upper:]' '[:lower:]')
    [[ "$answer" == y || "$answer" == yes ]] || { error 'Cancelled without moving listed files.'; return 1; }
    backup_root="$DOTFILES_BACKUP_DIR/$(date +%Y%m%d-%H%M%S)"
    mkdir -p -- "$backup_root"
    while IFS= read -r -d '' relative; do
        source="$HOME/$relative"; [[ -e "$source" || -L "$source" ]] || continue
        mkdir -p -- "$backup_root/$(dirname "$relative")"
        mv -- "$source" "$backup_root/$relative"
    done < "$TEMP_DIR/conflicts"
    success "Conflicts backed up to $backup_root"
}

setupDotfiles() {
    local index_sample changes upstream target
    require_commands git
    if [[ ! -e "$DOTFILES_DIR" ]]; then
        info 'Cloning the dotfiles bare repository...'
        git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"
    elif [[ ! -d "$DOTFILES_DIR" ]] || [[ "$(dotgit rev-parse --is-bare-repository 2>/dev/null || true)" != true ]]; then
        error "$DOTFILES_DIR exists but is not a valid bare repository."; error 'Move or rename it manually, then retry.'; return 1
    fi
    ensureDotfilesTracking
    restoreFastfetchOverrides
    make_temp_dir
    index_sample=$(dotgit ls-files | sed -n '1p')
    if [[ -z "$index_sample" ]]; then
        info 'Checking conflicts before the first checkout...'
        collect_conflicts HEAD
        backup_conflicts
        if ! dotgit checkout; then error 'Checkout failed after the backup attempt; stopping safely.'; return 1; fi
        success 'Bare repository checked out.'
        applySavedFastfetchPreferences || return 1
        return 0
    fi
    changes=$(dotgit status --porcelain=v1 --untracked-files=no)
    if [[ -n "$changes" ]]; then
        error 'Tracked dotfiles have local changes. Update stopped before merging; remote refs were refreshed.'
        printf '%s\n' "$changes"
        printf 'Inspect: git --git-dir=%q --work-tree=%q status --short\n' "$DOTFILES_DIR" "$HOME"
        printf 'Review:  git --git-dir=%q --work-tree=%q diff\n' "$DOTFILES_DIR" "$HOME"
        printf 'Save or resolve changes, then run setupDotfiles again.\n'
        return 1
    fi
    info 'Checking the latest dotfiles revision...'
    upstream=$(dotgit rev-parse --abbrev-ref --symbolic-full-name '@{upstream}') || { error 'No upstream configured; stopped safely.'; return 1; }
    target=$(dotgit rev-parse "$upstream")
    collect_conflicts "$target"
    backup_conflicts
    dotgit merge --ff-only "$target"
    success 'Bare repository is up to date.'
    applySavedFastfetchPreferences || return 1
}

setupZsh() {
    local repository name target
    require_commands git
    mkdir -p "$HOME/.zsh"
    while IFS= read -r repository; do
        name=$(basename "$repository"); target="$HOME/.zsh/$name"
        if [[ ! -d "$target" ]]; then git clone --depth=1 "https://github.com/$repository.git" "$target"
        elif [[ -d "$target/.git" ]]; then git -C "$target" pull --ff-only
        else error "$target is not a Git checkout; leaving it untouched."; return 1
        fi
    done <<< "$ZSH_PLUGIN_REPOS"
    success 'Zsh plugins are current.'
}
install_standalone_config() {
    local url="$1" destination="$2"
    require_commands curl install
    make_temp_dir; mkdir -p -- "$(dirname "$destination")"
    download_to "$url" "$TEMP_DIR/config" || { error "Download failed: $url"; return 1; }
    backup_existing_file "$destination"
    install -m 0644 "$TEMP_DIR/config" "$destination"
    success "Installed $destination"
}
setupNvim() { install_standalone_config 'https://raw.githubusercontent.com/gkuba/dotfiles/refs/heads/master/.config/nvim/init.lua' "$HOME/.config/nvim/init.lua"; }
setupFastfetch() {
    gatherFastfetchAnswers
    restoreFastfetchOverrides
    install_standalone_config 'https://raw.githubusercontent.com/gkuba/dotfiles/refs/heads/master/.config/fastfetch/config.jsonc' "$HOME/.config/fastfetch/config.jsonc" || return 1
    applyFastfetchAnswers
}
detect_package_manager() {
    local os_id os_like
    [[ -r /etc/os-release ]] || { error 'Cannot identify the OS: /etc/os-release is unavailable.'; return 1; }
    os_id=''; os_like=''
    while IFS='=' read -r key value; do
        value=${value%\"}; value=${value#\"}; value=${value%\'}; value=${value#\'}
        case "$key" in ID) os_id="$value" ;; ID_LIKE) os_like="$value" ;; esac
    done < /etc/os-release

    if [[ "$os_id" == arch || "$os_id" == cachyos || " $os_like " == *' arch '* ]]; then
        require_commands pacman sudo || return 1
        PACKAGE_MANAGER=pacman
    elif [[ "$os_id" == debian || "$os_id" == ubuntu || " $os_like " == *' debian '* || " $os_like " == *' ubuntu '* ]]; then
        require_commands apt-get sudo || return 1
        PACKAGE_MANAGER=apt
    else
        error "Unsupported OS for automatic package installation (ID=$os_id, ID_LIKE=$os_like). Supported package managers: pacman and apt."
        return 1
    fi
}
install_packages() {
    local package
    local -a unavailable=()
    detect_package_manager || return 1
    if [[ "$PACKAGE_MANAGER" == pacman ]]; then
        info 'Installing packages with pacman...'
        sudo pacman -Syu --needed --noconfirm "$@"
    else
        info 'Refreshing apt package lists...'
        sudo apt-get update
        for package in "$@"; do
            apt-cache show "$package" >/dev/null 2>&1 || unavailable+=("$package")
        done
        if ((${#unavailable[@]})); then
            error "These packages are unavailable in the enabled apt repositories: ${unavailable[*]}"
            error 'Enable the needed repository components or use a newer Debian/Ubuntu release; no package batch was installed.'
            return 1
        fi
        if ! command -v nala >/dev/null 2>&1; then
            info 'Installing Nala with apt...'
            sudo apt-get install -y nala || { error 'Could not install Nala with apt; no other packages were installed.'; return 1; }
        fi
        require_commands nala || return 1
        info 'Installing packages with Nala...'
        sudo nala install -y "$@"
    fi
}
installShellPackages() {
    detect_package_manager || return 1
    if [[ "$PACKAGE_MANAGER" == pacman ]]; then
        install_packages "${SHELL_PACKAGES[@]}" ttf-fira-code || return 1
    else
        install_packages "${SHELL_PACKAGES[@]}" fonts-firacode || return 1
    fi
    if command -v fc-cache >/dev/null 2>&1; then
        info 'Refreshing font cache...'
        fc-cache -f || { error 'Package installation succeeded, but refreshing the font cache failed.'; return 1; }
    fi
    success 'Shell packages are installed.'
}
configureLoginShell() {
    local zsh_path passwd_entry current_shell
    [[ "$CURRENT_USER" != root ]] || { error 'Run the dotfiles setup as your normal user, not root.'; return 1; }
    require_commands getent || return 1
    zsh_path=$(command -v zsh) || { error 'Zsh is not installed; install shell packages first.'; return 1; }
    [[ -x "$zsh_path" ]] || { error "Detected Zsh path is not executable: $zsh_path"; return 1; }
    passwd_entry=$(getent passwd "$CURRENT_USER") || { error "Could not look up account: $CURRENT_USER"; return 1; }
    current_shell=${passwd_entry##*:}
    if [[ "$current_shell" == "$zsh_path" ]]; then
        success 'Zsh is already the login shell.'
        return 0
    fi
    require_commands grep sudo usermod || return 1
    grep -Fxq -- "$zsh_path" /etc/shells || { error "Zsh path is not listed in /etc/shells: $zsh_path"; return 1; }
    info "Changing the login shell for $CURRENT_USER to $zsh_path..."
    sudo usermod --shell "$zsh_path" "$CURRENT_USER" || { error 'Could not change the login shell.'; return 1; }
    passwd_entry=$(getent passwd "$CURRENT_USER") || { error "Could not verify account: $CURRENT_USER"; return 1; }
    [[ "${passwd_entry##*:}" == "$zsh_path" ]] || { error 'The account database did not report the Zsh shell change.'; return 1; }
    success 'Zsh is now the login shell. Log out and back in for it to take effect.'
}
setupStarship() {
    local config_file
    require_commands curl
    if ! command -v starship >/dev/null 2>&1; then
        install_packages starship || return 1
    fi
    require_commands starship || return 1
    CURRENT_HOST=$(uname -n)
    case "$CURRENT_HOST" in pixel) config_file='pixel-starship.toml' ;; pi|pi-*|raspberrypi*|pixelshed) config_file='pi-starship.toml' ;; *) config_file='starship.toml' ;; esac
    info "Selecting Starship config for $CURRENT_HOST ($config_file)..."
    install_standalone_config "$STARSHIP_CONFIG_REPO/$config_file" "$HOME/.config/starship.toml"
}

updateHostsFile() {
    local downloaded base candidate backup
    require_commands curl awk sudo install
    make_temp_dir
    downloaded="$TEMP_DIR/hosts"; base="$TEMP_DIR/base"; candidate="$TEMP_DIR/candidate"
    download_to "$HOSTS_GIST_URL" "$downloaded" || { error 'Hosts download failed; no changes made.'; return 1; }
    if ! awk -v start="$HOSTS_BLOCK_START" -v end="$HOSTS_BLOCK_END" '
        $0 == start { if (inside || starts++) bad=1; inside=1; next }
        $0 == end { if (!inside || ends++) bad=1; inside=0; next }
        END { if (inside || starts != ends || bad) exit 1 }
    ' /etc/hosts; then
        error 'The existing managed hosts markers are invalid, nested, or out of order; /etc/hosts was not changed.'
        return 1
    fi
    awk -v start="$HOSTS_BLOCK_START" -v end="$HOSTS_BLOCK_END" '
        $0==start {inside=1; next}
        $0==end {inside=0; next}
        !inside { if (NF==0) { blanks++; next } while (blanks--) print ""; blanks=0; print }
    ' /etc/hosts > "$base"
    { cat "$base"; printf '\n%s\n' "$HOSTS_BLOCK_START"; awk 'NF && $1 !~ /^#/ && $1!="127.0.0.1" && $1!="::1" && $1!="localhost"{print}' "$downloaded"; printf '%s\n' "$HOSTS_BLOCK_END"; } > "$candidate"
    backup="/etc/hosts.bak.$(date +%Y%m%d-%H%M%S)"
    sudo cp -a /etc/hosts "$backup"; sudo install -m 0644 "$candidate" /etc/hosts
    success "Managed hosts block updated; backup: $backup"
}
gatherWizardAnswers() {
    if ask_yes_no 'Set Zsh as the login shell?' yes; then RUN_LOGIN_SHELL=true; fi
    if ask_yes_no 'Update the managed /etc/hosts block from the Gist?' no; then RUN_HOSTS=true; fi
    gatherFastfetchAnswers
}
run_step() {
    local label="$1" action="$2"; shift 2
    [[ "$TTY" == true && "$label" != 'Finalizing' ]] && draw_screen "$label"
    if [[ "$label" == 'Installing Shell Packages' || "$label" == 'Configuring Starship' ]]; then
        run_in_output_region "$action" "$@"
    else
        "$action" "$@"
    fi
    COMPLETED="$COMPLETED$label|"
    if [[ "$label" == 'Finalizing' ]]; then mark_final_step_complete; fi
    [[ "$label" == 'Finalizing' ]] || mark_active_step_complete "$label"
    return 0
}
run_interactive_setup() {
    local -a plan_lines
    [[ "$TTY" == true ]] && clear
    draw_screen 'Gathering Information'
    info_identity OS "$CURRENT_OS"
    info_identity User "$CURRENT_USER"
    info_identity Hostname "$CURRENT_HOST"
    printf '\n'
    gatherWizardAnswers
    COMPLETED='|Gathering Information|'
    draw_screen 'Installing Shell Packages'
    plan_lines=('Install shell tools with pacman or apt' 'Install Nala first on apt-based systems')
    [[ "$RUN_LOGIN_SHELL" == true ]] && plan_lines+=('Set Zsh as the login shell if needed')
    plan_lines+=('Update bare dotfiles repo and deploy tracked config' 'Sync Zsh plugin checkouts' 'Apply Fastfetch image preferences' "Select Starship config for $CURRENT_HOST")
    panel 'Setup Plan' "${plan_lines[@]}"
    [[ "$RUN_HOSTS" == true ]] && panel 'Hosts file' 'Replace the managed block and back up current file'
    confirm_plan || { info 'Setup cancelled; no changes were made.'; return 0; }
    run_step 'Installing Shell Packages' installShellPackages
    if [[ "$RUN_LOGIN_SHELL" == true ]]; then run_step 'Configuring Login Shell' configureLoginShell; fi
    run_step 'Updating Dotfiles' setupDotfiles
    run_step 'Configuring Fastfetch' applyFastfetchAnswers
    run_step 'Syncing Zsh Plugins' setupZsh
    run_step 'Configuring Starship' setupStarship
    if [[ "$RUN_HOSTS" == true ]]; then run_step 'Updating Hosts File' updateHostsFile; fi
    run_step 'Finalizing' true
    success 'Dotfiles setup completed successfully.'
}
run_named_action() {
    local action="$1" label
    case "$action" in
        installShellPackages) label='Installing Shell Packages' ;;
        configureLoginShell) label='Configuring Login Shell' ;;
        setupDotfiles) label='Updating Dotfiles' ;;
        setupZsh) label='Syncing Zsh Plugins' ;;
        setupNvim) label='Configuring Neovim' ;;
        setupFastfetch) label='Configuring Fastfetch' ;;
        setupStarship) label='Configuring Starship' ;;
        updateHostsFile) label='Updating Hosts File' ;;
    esac
    SINGLE_ACTION=true
    SINGLE_LABEL="$label"
    draw_screen "$label"
    panel 'Selected Action' "$action"
    confirm_plan || { info 'Setup cancelled; no changes were made.'; return 0; }
    if [[ "$action" == installShellPackages || "$action" == setupStarship ]]; then
        SCREEN_OUTPUT_TOP=$((SCREEN_OUTPUT_TOP + 4))
        run_in_output_region "$action"
    else
        "$action"
    fi
    COMPLETED="$COMPLETED$label|"
    success "$action completed successfully."
}
main() {
    init_terminal
    CURRENT_USER=$(id -un); CURRENT_HOST=$(uname -n)
    CURRENT_OS=$(. /etc/os-release 2>/dev/null; printf '%s' "${PRETTY_NAME:-${NAME:-Linux}}")
    if (($# == 0)); then run_interactive_setup; return; fi
    if (($# != 1)); then error 'Pass one action at a time.'; show_help; return 2; fi
    case "$1" in
        --help|-h) show_help ;;
        installShellPackages|configureLoginShell|setupDotfiles|setupZsh|setupNvim|setupFastfetch|setupStarship|updateHostsFile) run_named_action "$1" ;;
        *) error "Unknown action: $1"; show_help; return 2 ;;
    esac
}
main "$@"
printf '\n'
