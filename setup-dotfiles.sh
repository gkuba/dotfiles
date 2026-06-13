#!/usr/bin/env bash
# =============================================================================
# Dotfiles Setup Script - Interactive & Streamlined
# =============================================================================
set -euo pipefail

# ── Colors ─────────────────────────────────────────────────────────────────────
RED="\033[0;31m"
GREEN="\033[0;32m"
YELLOW="\033[0;33m"
BLUE="\033[0;34m"
MAGENTA="\033[0;35m"
CYAN="\033[0;36m"
WHITE="\033[0;37m"
RESET="\033[0m"

info()    { echo -e "${BLUE}[INFO]${RESET} $*"; }
success() { echo -e "${GREEN}[OK]${RESET} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${RESET} $*"; }
error()   { echo -e "${RED}[ERROR]${RESET} $*" >&2; }

clear
echo -e "${MAGENTA}===================================================${RESET}"
echo -e "${CYAN} Dotfiles Setup Script${RESET}"
echo -e "${MAGENTA}===================================================${RESET}"
echo

info "Gathering system information..."
CURRENT_USER=$(whoami)
CURRENT_SHELL=$(basename "$SHELL")
ZSH_INSTALLED=false
if command -v zsh >/dev/null 2>&1; then
    ZSH_INSTALLED=true
fi

echo
echo -e "User: ${GREEN}$CURRENT_USER${RESET}"
echo -e "Current Shell: ${YELLOW}$CURRENT_SHELL${RESET}"
echo -e "Zsh Installed: $( [[ "$ZSH_INSTALLED" == true ]] && echo "${GREEN}Yes${RESET}" || echo "${RED}No${RESET}" )"

# ── Parse flags ────────────────────────────────────────────────────────────────
RUN_DOTGIT=false
RUN_ZSH=false
RUN_NVIM=false
RUN_FASTFETCH=false
RUN_STARSHIP=false
RUN_HOSTS=false

if [[ $# -eq 0 ]]; then
    RUN_DOTGIT=true
    RUN_ZSH=true
    RUN_NVIM=true
    RUN_FASTFETCH=true
    RUN_STARSHIP=true
else
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dotgit)    RUN_DOTGIT=true ;;
            --zsh)       RUN_ZSH=true ;;
            --nvim)      RUN_NVIM=true ;;
            --fastfetch) RUN_FASTFETCH=true ;;
            --starship)  RUN_STARSHIP=true ;;
            --hosts)     RUN_HOSTS=true ;;
            --all)
                RUN_DOTGIT=true
                RUN_ZSH=true
                RUN_NVIM=true
                RUN_FASTFETCH=true
                RUN_STARSHIP=true
                RUN_HOSTS=true
                ;;
            *) error "Unknown option: $1"; exit 1 ;;
        esac
        shift
    done
fi

echo
echo -e "${CYAN}The following actions will be performed:${RESET}"
[[ "$RUN_DOTGIT" == true ]]    && echo " • Setup bare git repository & pull all configs"
[[ "$RUN_ZSH" == true ]]       && echo " • Install/Update Zsh plugins"
[[ "$RUN_NVIM" == true ]]      && echo " • Setup Neovim config (standalone curl fallback)"
[[ "$RUN_FASTFETCH" == true ]] && echo " • Setup fastfetch config (standalone curl fallback)"
[[ "$RUN_STARSHIP" == true ]]  && echo " • Install Starship + theme"
[[ "$RUN_HOSTS" == true ]]     && echo " • Update /etc/hosts from Gist"

# ── Ask about changing shell to Zsh ───────────────────────────────────────────
if [[ "$ZSH_INSTALLED" == true && "$CURRENT_SHELL" != "zsh" ]]; then
    echo
    read -r -p "Would you like to change your default shell to Zsh? (y/N): " change_shell
    if [[ "$change_shell" =~ ^[Yy]$ ]]; then
        CHANGE_TO_ZSH=true
        echo -e "${GREEN}→ Will change default shell to Zsh${RESET}"
    else
        CHANGE_TO_ZSH=false
    fi
else
    CHANGE_TO_ZSH=false
fi

# ── Hosts file prompt (only if not using --all or --hosts flag) ───────────────
if [[ "$RUN_HOSTS" == false ]]; then
    echo
    read -r -p "Update /etc/hosts by appending entries from GitHub Gist? (y/N): " update_hosts
    if [[ "$update_hosts" =~ ^[Yy]$ ]]; then
        RUN_HOSTS=true
    fi
fi

# ── Wallpaper Setup Prompt (Conditional on Bare Repo pull) ────────────────────
KEEP_WALLPAPERS=false
if [[ "$RUN_DOTGIT" == true ]]; then
    echo
    read -r -p "Keep Wallpapers from dotfiles repo and symlink to ~/Pictures/Wallpapers? (y/N): " choice_wallpapers
    if [[ "$choice_wallpapers" =~ ^[Yy]$ ]]; then
        KEEP_WALLPAPERS=true
        echo -e "${GREEN}→ Will keep and map Wallpapers directory${RESET}"
    else
        echo -e "${RED}→ Will purge ~/Wallpapers directory post-clone${RESET}"
    fi
fi

echo
read -r -p "Press [Enter] to proceed with setup, or type 'Q' to quit: " confirm
if [[ "$confirm" =~ ^[Qq]$ ]]; then
    echo "Setup cancelled by user."
    exit 0
fi

echo
info "Starting setup..."

# ── Temporary dotgit function ─────────────────────────────────────────────────
dotgit() {
    /usr/bin/git --git-dir="$HOME/dotfiles/" --work-tree="$HOME" "$@"
}

# ── Update Hosts File (APPEND only) ───────────────────────────────────────────
updateHostsFile() {
    info "Updating /etc/hosts from GitHub Gist (appending custom entries)..."

    # Backup current hosts file
    sudo cp /etc/hosts "/etc/hosts.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true

    # Download gist and append (skip localhost lines to prevent duplicates)
    if sudo curl -fsSL https://gist.githubusercontent.com/gkuba/328f47706216baaf6cdc6c5519bf84c2/raw/3c1ea40b581072ba0218140d4ceff47a55744b3c/gistfile1.txt \
        -o /tmp/hosts-gist.tmp; then

        echo -e "\n# === Custom hosts from GitHub Gist (added $(date)) ===" | sudo tee -a /etc/hosts > /dev/null

        sudo grep -vE '^(127\.0\.0\.1|::1|localhost|#)' /tmp/hosts-gist.tmp | \
            sudo tee -a /etc/hosts > /dev/null

        sudo rm -f /tmp/hosts-gist.tmp
        success "/etc/hosts updated successfully (custom entries appended)"
    else
        error "Failed to download hosts file from Gist"
    fi
}

# ── Cleanup old standalone files (Only triggers if bare repository isn't active) ─
cleanup_old_files() {
    if [[ "$RUN_NVIM" == true && "$RUN_DOTGIT" == false ]]; then
        rm -rf "$HOME/.config/nvim"
    fi
    if [[ "$RUN_FASTFETCH" == true && "$RUN_DOTGIT" == false ]]; then
        rm -f "$HOME/.config/fastfetch/config.jsonc"
    fi
}
cleanup_old_files

# ── Setup Functions ───────────────────────────────────────────────────────────
setup_dotgit() {
    info "Setting up bare dotfiles repository..."
    if [[ ! -d "$HOME/dotfiles" ]]; then
        mkdir -p "$HOME/dotfiles"
        git clone --bare https://github.com/gkuba/dotfiles.git "$HOME/dotfiles"
        success "Cloned bare repository"
    else
        warn "Bare repo folder already exists."
    fi

    dotgit config --local status.showUntrackedFiles no

    # Safe Checkout Strategy: Gracefully move existing system skeleton files aside
    if ! dotgit checkout 2>/dev/null; then
        warn "Pre-existing files detected. Moving structural conflicts to backup stash..."
        mkdir -p "$HOME/.dotfiles-backup"
        dotgit checkout 2>&1 | grep -E "^\s" | awk '{print $1}' | while read -r conflicting_file; do
            if [[ -f "$HOME/$conflicting_file" ]]; then
                mkdir -p "$HOME/.dotfiles-backup/$(dirname "$conflicting_file")"
                mv "$HOME/$conflicting_file" "$HOME/.dotfiles-backup/$conflicting_file"
            fi
        done
        dotgit checkout
    fi
    success "Dotfiles verified and fully deployed via Bare Repository"
}

setup_zsh() {
    info "Syncing Zsh plugins..."
    mkdir -p "$HOME/.zsh"

    local plugins=(
        "zsh-users/zsh-autosuggestions"
        "zsh-users/zsh-syntax-highlighting"
        "zsh-users/zsh-history-substring-search"
    )

    for plugin in "${plugins[@]}"; do
        local name="${plugin##*/}"
        local target="$HOME/.zsh/$name"
        if [[ ! -d "$target" ]]; then
            git clone --depth=1 "https://github.com/$plugin.git" "$target"
        else
            git -C "$target" pull --ff-only
        fi
    done
    success "Zsh plugins configured"
}

setup_nvim() {
    if [[ "$RUN_DOTGIT" == false ]]; then
        info "Setting up Neovim (Standalone Mode)..."
        mkdir -p "$HOME/.config/nvim"
        curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/refs/heads/master/.config/nvim/init.lua \
            -o "$HOME/.config/nvim/init.lua"
        success "Downloaded init.lua standalone"
    fi
}

setup_fastfetch() {
    if [[ "$RUN_DOTGIT" == false ]]; then
        info "Setting up fastfetch (Standalone Mode)..."
        mkdir -p "$HOME/.config/fastfetch"
        curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/refs/heads/master/.config/fastfetch/config.jsonc \
            -o "$HOME/.config/fastfetch/config.jsonc"
        success "Downloaded fastfetch config standalone"
    fi
}

setup_starship() {
    info "Installing Starship..."
    sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y
    mkdir -p "$HOME/.config"

    local actual_hostname=$(uname -n)
    local url=""

    case "$actual_hostname" in
        pixel) url="pixel-starship.toml" ;;
        *pi*|pixelshed) url="pi-starship.toml" ;;
        *) url="starship.toml" ;;
    esac

    curl -sS "https://raw.githubusercontent.com/gkuba/Starship-Configs/main/$url" \
        -o "$HOME/.config/starship.toml"
    success "Starship installed and configured for node: $actual_hostname"
}

# ── Consistent Wallpaper Setup Function ───────────────────────────────────────
setup_wallpapers() {
    local wallpapers_source="$HOME/Wallpapers"
    local pictures_dir="$HOME/Pictures"
    local target_link="$pictures_dir/Wallpapers"

    if [[ "$KEEP_WALLPAPERS" == true ]]; then
        if [[ -d "$wallpapers_source" ]]; then
            info "Processing Wallpaper assets and handling symlink mapping..."
            mkdir -p "$pictures_dir"

            # Check and clear conflicting target paths safely
            if [[ -L "$target_link" ]]; then
                rm "$target_link"
            elif [[ -d "$target_link" ]]; then
                warn "Physical path exists at $target_link. Stashing to $target_link.bak..."
                mv "$target_link" "${target_link}.bak"
            fi

            ln -s "$wallpapers_source" "$target_link"
            success "Wallpapers systematically mapped to $target_link"
        else
            warn "Wallpaper configuration was flagged, but ~/Wallpapers directory wasn't deployed by Git."
        fi
    else
        # Purge the directory if user explicitly declined keeping them
        if [[ -d "$wallpapers_source" ]]; then
            info "Purging local source folder asset files from home tree..."
            rm -rf "$wallpapers_source"
            success "Unused ~/Wallpapers storage cleared cleanly"
        fi
    fi
}

# ── Main Execution ─────────────────────────────────────────────────────────────
[[ "$RUN_DOTGIT" == true ]]    && setup_dotgit
[[ "$RUN_ZSH" == true ]]       && setup_zsh
[[ "$RUN_NVIM" == true ]]      && setup_nvim
[[ "$RUN_FASTFETCH" == true ]] && setup_fastfetch
[[ "$RUN_STARSHIP" == true ]]  && setup_starship
[[ "$RUN_HOSTS" == true ]]     && updateHostsFile

# Safely fire wallpaper logic using the updated function name
[[ "$RUN_DOTGIT" == true ]]    && setup_wallpapers

# ── Change Shell Section (Bulletproof Logic) ───────────────────────────────────
if [[ "$CHANGE_TO_ZSH" == true ]]; then
    echo
    info "Updating default user shell account space to /usr/bin/zsh..."

    target_user=$(whoami)

    # Execute natively without blind sudo profile masks
    if chsh -s /usr/bin/zsh "$target_user"; then
        success "Default user login shell mapped to Zsh successfully!"
        echo -e "${YELLOW}Note: Please log out and log back in (or reboot) for Zsh to fully take effect.${RESET}"
    else
        error "Failed to modify shell access database dynamically. Trying fallback entry..."
        sudo chsh -s /usr/bin/zsh "$target_user"
        success "Default shell fallback successfully updated to Zsh via sudo."
    fi
fi

echo
success "========================================"
success " Setup completed successfully! "
success "========================================"
