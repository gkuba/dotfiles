#!/usr/bin/env bash
# =============================================================================
# Dotfiles Setup Script - Interactive
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
[[ "$RUN_DOTGIT" == true ]]    && echo " • Setup bare git repository"
[[ "$RUN_ZSH" == true ]]       && echo " • Install Zsh plugins"
[[ "$RUN_NVIM" == true ]]      && echo " • Setup Neovim config"
[[ "$RUN_FASTFETCH" == true ]] && echo " • Setup fastfetch config"
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
        
        rm -f /tmp/hosts-gist.tmp
        success "/etc/hosts updated successfully (custom entries appended)"
    else
        error "Failed to download hosts file from Gist"
    fi
}

# ── Cleanup old files ─────────────────────────────────────────────────────────
cleanup_old_files() {
    rm -rf "$HOME/.zsh/zsh-autosuggestions" \
           "$HOME/.zsh/zsh-syntax-highlighting" \
           "$HOME/.zsh/zsh-history-substring-search"
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
        warn "Bare repo already exists"
    fi
    dotgit config --local status.showUntrackedFiles no
}

setup_zsh() {
    info "Installing Zsh plugins..."
    mkdir -p "$HOME/.zsh"
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions.git "$HOME/.zsh/zsh-autosuggestions" 2>/dev/null || true
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting.git "$HOME/.zsh/zsh-syntax-highlighting" 2>/dev/null || true
    git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search.git "$HOME/.zsh/zsh-history-substring-search" 2>/dev/null || true
    success "Zsh plugins installed"
}

setup_nvim() {
    info "Setting up Neovim..."
    mkdir -p "$HOME/.config/nvim"
    if [[ "$RUN_DOTGIT" == false ]]; then
        curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/refs/heads/master/.config/nvim/init.lua \
            -o "$HOME/.config/nvim/init.lua"
        success "Downloaded init.lua"
    else
        dotgit checkout -f
        success "Neovim config pulled via dotgit"
    fi
}

setup_fastfetch() {
    info "Setting up fastfetch..."
    mkdir -p "$HOME/.config/fastfetch"
    if [[ "$RUN_DOTGIT" == false ]]; then
        curl -sS https://raw.githubusercontent.com/gkuba/dotfiles/refs/heads/master/.config/fastfetch/config.jsonc \
            -o "$HOME/.config/fastfetch/config.jsonc"
        success "Downloaded fastfetch config"
    else
        dotgit checkout -f
        success "Fastfetch config pulled via dotgit"
    fi
}

setup_starship() {
    info "Installing Starship..."
    sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y
    mkdir -p "$HOME/.config"
    case "$HOSTNAME" in
        pixel) url="pixel-starship.toml" ;;
        *pi*|pixelshed) url="pi-starship.toml" ;;
        *) url="starship.toml" ;;
    esac
    curl -sS "https://raw.githubusercontent.com/gkuba/Starship-Configs/main/$url" \
        -o "$HOME/.config/starship.toml"
    success "Starship installed and configured"
}

# ── Main Execution ─────────────────────────────────────────────────────────────
[[ "$RUN_DOTGIT" == true ]]    && setup_dotgit
[[ "$RUN_ZSH" == true ]]       && setup_zsh
[[ "$RUN_NVIM" == true ]]      && setup_nvim
[[ "$RUN_FASTFETCH" == true ]] && setup_fastfetch
[[ "$RUN_STARSHIP" == true ]]  && setup_starship
[[ "$RUN_HOSTS" == true ]]     && updateHostsFile

# Change shell if requested
if [[ "$CHANGE_TO_ZSH" == true ]]; then
    info "Changing default shell to Zsh..."
    chsh -s "$(command -v zsh)"
    success "Default shell changed to Zsh. Please log out and back in."
fi

echo
success "========================================"
success " Setup completed successfully! "
success "========================================"

if [[ "$CHANGE_TO_ZSH" == true ]]; then
    echo -e "${YELLOW}Note: Log out and log back in (or reboot) to use Zsh.${RESET}"
fi
