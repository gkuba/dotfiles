# =============================================================================
# ~/.zshrc
# =============================================================================

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# ─────────────────────────────────────────────
# Fastfetch on terminal startup
# ─────────────────────────────────────────────
fastfetch

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
eval "$(starship init zsh)"

# ─────────────────────────────────────────────
# fzf integration
# ─────────────────────────────────────────────
eval "$(fzf --zsh)"

# ─────────────────────────────────────────────
# Fish-like autosuggestions + syntax highlighting
# ─────────────────────────────────────────────
source ~/.zsh/zsh-autosuggestions/zsh-autosuggestions.zsh
source ~/.zsh/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
source ~/.zsh/zsh-history-substring-search/zsh-history-substring-search.zsh

# Style autosuggestions to be subtle gray (matches your dark theme)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=240'

# ─────────────────────────────────────────────
# Autosuggestions settings
# ─────────────────────────────────────────────
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_STRATEGY=(history completion)

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
