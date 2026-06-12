## If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Run fastfetch on interactive terminal startup
fastfetch

##-------------------------------------------------------------
## Some Settings
##-------------------------------------------------------------
shopt -s checkhash checkwinsize cdspell dirspell histappend dotglob no_empty_cmd_completion

## HISTORY
HISTCONTROL=ignoredups:ignorespace

##-------------------------------------------------------------
## Sourced files (Streamlined Array Loop)
##-------------------------------------------------------------
for config_file in .shell_colors .shell_environment .shell_functions .shell_aliases; do
    [[ -f "$HOME/$config_file" ]] && source "$HOME/$config_file"
done
unset config_file

## Enable programmable completion features.
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        source /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        source /etc/bash_completion
    fi
fi

## Starship Command Prompt & Integrations
eval "$(starship init bash)"
eval "$(fzf --bash)"
