# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=1000
HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# Alias definitions.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# use vim
export VISUAL=nvim;
export EDITOR=nvim;

# Path to the bash it configuration
export BASH_IT="$HOME/.bash_it"

# Lock and Load a custom theme file.
# Leave empty to disable theming.
# location /.bash_it/themes/
export BASH_IT_THEME='tbe'

# Load Bash It
source "$BASH_IT"/bash_it.sh

alias tmux='tmux -2'
export SRC="~/src"
export SEC="mnt/sec/src"

# pyenv
if [ -x "$(command -v pyenv)" ]; then
	echo "pyenv found.."
	export PATH="$HOME/.pyenv/bin:$PATH"
	command -v pyenv >/dev/null || export PATH="$PYENV_ROOT/bin:$PATH"
	eval "$(pyenv init -)"
fi

if command -v fzf-share >/dev/null; then
  source "$(fzf-share)/key-bindings.bash"
  source "$(fzf-share)/completion.bash"
fi

set -o vi

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

bind '"\t":menu-complete'
bind '"\e[Z": menu-complete-backward'
bind "TAB:menu-complete"
bind "set show-all-if-ambiguous on"
bind "set completion-ignore-case on"
bind "set menu-complete-display-prefix on"

function cdup
{
    amt=$1
    cmd=""
    i=0
    while [ "$i" -lt "$amt" ]
    do
            cmd=$cmd"../"
            let i=$i+1
    done

    cd $cmd
}

. /home/timon/.nix-profile/etc/profile.d/nix.sh
