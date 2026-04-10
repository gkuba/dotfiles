## If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Run fastfetch on interactive terminal startup
fastfetch

##-------------------------------------------------------------
## Some Settings
##-------------------------------------------------------------

## Bash
shopt -s checkhash    # bash will check hash table for command before searching path
shopt -s checkwinsize # update window size after each command

## CD
shopt -s cdspell # Correct errors in directory names when using CD
shopt -s dirspell # spelling correction on directory names during word completion

## HISTORY
HISTCONTROL=ignoredups:ignorespace # don't put duplicate lines in the history.
shopt -s histappend # append to the history file, don't overwrite it

## Expansion
shopt -s dotglob # include filenames beginning with a `.' in the results of filename expansion.
shopt -s no_empty_cmd_completion # do not attempt to auto complete empty command line


##-------------------------------------------------------------
## Sourced files.
##-------------------------------------------------------------

## Source ~/.bash_colors for both bash and zsh
if [ -f ~/.shell_colors ]; then
    . ~/.shell_colors
fi

## Source ~/.shell_enviroment for both bash and zsh
if [ -f ~/.shell_environment ]; then
    . ~/.shell_environment
fi

## Source ~/.shell_bash_functions for both bash and zsh
if [ -f ~/.shell_functions ]; then
    . ~/.shell_functions
fi

## Source ~/.shell_aliases for both bash and zsh
if [ -f ~/.shell_aliases ]; then
    . ~/.shell_aliases
fi

## Enable programmable completion features.
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

## Starship Command Prompt
eval "$(starship init bash)"
eval "$(fzf --bash)"
