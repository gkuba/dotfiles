## Set up the prompt -- Default prompt
#autoload -Uz promptinit
#promptinit
#prompt adam1

## Starship prompt
eval "$(starship init zsh)"

## zsh pulgins for autosuggestion and syntax highliting in prompt.
source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

## Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history
setopt histignorealldups sharehistory

## Use modern completion system
autoload -Uz compinit
compinit

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'

## Source ~/.shell_colors for both bash and zsh
if [ -f ~/.shell_colors ]; then
    . ~/.shell_colors
fi

## Source ~/.shell_enviroment for both bash and zsh
if [ -f ~/.shell_enviroment ]; then
    . ~/.shell_enviroment
fi

## Source ~/.shell_functions for both bash and zsh
if [ -f ~/.shell_functions ] ; then
    . ~/.shell_functions
fi

## Source ~/.shell_aliases for both bash and zsh
if [ -f ~/.shell_aliases ]; then
    . ~/.shell_aliases
fi
