# =============================================================================
# ~/.zshrc
# =============================================================================

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ─────────────────────────────────────────────
# Fastfetch on terminal startup
# ─────────────────────────────────────────────
if command -v fastfetch >/dev/null 2>&1; then
    # Hyprland gets its own layout (WM row, no logo top padding)
    if [[ -n "$HYPRLAND_INSTANCE_SIGNATURE" && -f ~/.config/fastfetch/hyprland.jsonc ]]; then
        fastfetch -c ~/.config/fastfetch/hyprland.jsonc
    else
        fastfetch
    fi
fi

# ─────────────────────────────────────────────
# Source common shell files
# ─────────────────────────────────────────────
[[ -f ~/.shell_colors ]] && source ~/.shell_colors
[[ -f ~/.shell_environment ]] && source ~/.shell_environment
[[ -f ~/.shell_functions ]] && source ~/.shell_functions
[[ -f ~/.shell_aliases ]] && source ~/.shell_aliases

# ─────────────────────────────────────────────
# Zsh Options (converted from your old shopt settings)
# ─────────────────────────────────────────────
setopt correct                  # spelling correction
setopt glob_dots                # include hidden files in globbing
setopt hist_ignore_dups         # ignore duplicate history entries
setopt hist_ignore_space        # ignore commands starting with space
setopt append_history           # append instead of overwrite
setopt share_history            # share history between sessions
setopt extended_history         # save timestamps
setopt autocd                   # cd by just typing directory name
setopt interactive_comments     # allow comments in interactive shell

# ─────────────────────────────────────────────
# Starship Prompt
# ─────────────────────────────────────────────
if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi

# ─────────────────────────────────────────────
# fzf integration
# ─────────────────────────────────────────────
if command -v fzf >/dev/null 2>&1; then
    eval "$(fzf --zsh)"
fi

# ─────────────────────────────────────────────
# Autosuggestions settings
# ─────────────────────────────────────────────
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

# ─────────────────────────────────────────────
# Fish-like autosuggestions + history search
# ─────────────────────────────────────────────
[[ -r ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && source ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh

# ─────────────────────────────────────────────
# History settings
# ─────────────────────────────────────────────
HISTSIZE=10000
SAVEHIST=10000
HISTFILE=~/.zsh_history

# ─────────────────────────────────────────────
# Key bindings
# ─────────────────────────────────────────────
bindkey '^[[A' history-substring-search-up   # Up arrow
bindkey '^[[B' history-substring-search-down # Down arrow

# ── Line Navigation ──────────────────────────
bindkey '^[[H' beginning-of-line          # Home
bindkey '^[[F' end-of-line                # End
bindkey '^[[3~' delete-char

# Alternative sequences (helps with Ghostty compatibility)
bindkey '^[OH' beginning-of-line
bindkey '^[OF' end-of-line

# Load syntax highlighting last so it can wrap widgets from earlier plugins.
[[ -r ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
