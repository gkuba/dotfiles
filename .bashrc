## If not running interactively, don't do anything
[[ $- != *i* ]] && return
##-------------------------------------------------------------
## Some Settings
##-------------------------------------------------------------

## Bash
shopt -s checkhash    # bash will check hash table for command before searching path
shopt -s checkwinsize # update window size after each command

## CD
shopt -s cdspell # Correct errors in directory names when using CD
#shopt -s cdable_vars			# Enable cd to use variable expansion
shopt -s dirspell # spelling correction on directory names during word completion

## HISTORY
HISTCONTROL=ignoredups:ignorespace # don't put duplicate lines in the history.
#HISTSIZE=1000
#HISTFILESIZE=2000
shopt -s histappend # append to the history file, don't overwrite it
#shopt -s cmdhist			# save all lines of a multi-line command in the same history entry. (Default set)

## Expansion
shopt -s dotglob # include filenames beginning with a `.' in the results of filename expansion.
#shopt -s expand_aliases		# allow expansion of bash aliases (Default set)
#shopt -s extglob			# required for programable expansion (Default set)
shopt -s no_empty_cmd_completion # do not attempt to auto complete empty command line
#shopt -s nocaseglob			# match as case insensitive when expanding file names
#shopt -s nocasematch			# matches patterns as case-insensitive matching while executing case or [[ conditional commands.

## Mail
#shopt -u mailwarn
#unset MAILCHECK

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

##-------------------------------------------------------------
## Shell Prompt
##-------------------------------------------------------------
## Old prompt here for reuse later.
# function pre_prompt {
# newPWD="${PWD}"
# user=$(whoami)
# host=$(echo -n $HOSTNAME | sed -e "s/[\.].*//")
#
# let promptsize=$(echo -n "┌─[ $newPWD ]──[ $user@$host ]─┐" | wc -m | tr -d " ")
# let fillsize=${COLUMNS}-${promptsize}
# fill=""
# while [ "$fillsize" -gt "0" ]
# do
#     fill="${fill}─"
#         let fillsize=${fillsize}-1
# done
# if [ "$fillsize" -lt "0" ]
# then
#     let cutt=3-${fillsize}
#     newPWD="...$(echo -n $PWD | sed -e "s/\(^.\{$cutt\}\)\(.*\)/\2/")"
# fi
#
# }
#
# PROMPT_COMMAND=pre_prompt		# run pre_prompt before the bash prompt is created
#
#
# case "$TERM" in
# xterm-256color)
#     PS1="\n$darkpurple┌─( $grapefruit\${newPWD} $darkpurple)─\${fill}─( $smoothgreen\${user}$white@$iceblue\${host} $darkpurple)─┐\n$darkpurple└─[ $white\$(date \"+%r\") $darkpurple]─>$white "
#     ;;
# screen-256color)
#     PS1="\n$cyan┌─( $green\${newPWD} $cyan)─\${fill}─( $orange\${user}$white@$magenta\${host} $cyan)─┐\n$cyan└─[ $white\$(date \"+%r\") $cyan]─>$white "
#     ;;
#     *)
#     PS1="\n┌─( \${newPWD} )─\${fill}─( \${user}@\${host} )─┐\n└─[ \$(date \"+%r\") ]─> "
#     ;;
# esac

## Starship Command Prompt
eval "$(starship init bash)"
