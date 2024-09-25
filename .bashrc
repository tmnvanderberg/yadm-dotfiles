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
HISTSIZE=-1
HISTFILESIZE=-1

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

export HISTTIMEFORMAT="[%F %T] "
# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.bash_eternal_history
# Force prompt to write history after every command.
# http://superuser.com/questions/20900/bash-history-loss
PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

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

if command -v fzf-share >/dev/null; then
  source "$(fzf-share)/key-bindings.bash"
  source "$(fzf-share)/completion.bash"
fi

[ -f ~/.fzf.bash ] && source ~/.fzf.bash

function uart
{
    local dev
    dev=$(find /dev/tty* -print 2>/dev/null | sed 's/^.\///' | fzf +m) 
    if [ -n "$dev" ]; then
	picocom -b 115200 "$dev" || return 1 
    fi
}

function st
{
    local dir
    dir=$(find `readlink -f /src/1` `readlink -f /src/2` `readlink -f /src/3` -type d -maxdepth 2 -print 2>/dev/null | sed 's/^.\///' | fzf +m) 
    cd "$dir" || return 1 
    ls -p --color=auto
}

# load nix profile if it's available
NIX_PROFILE="/home/timon/.nix-profile/etc/profile.d/nix.sh"
[ -f "$NIX_PROFILE" ] && . "$NIX_PROFILE"

# for using latest neovim release
export PATH="$PATH:/opt/nvim-linux64/bin"

# Start SSH agent
if [ -z "$SSH_AUTH_SOCK" ] ; then
    eval $(ssh-agent -s)
    ssh-add
fi

# Start ssh-agent if not already running
if ! pgrep -u "$USER" ssh-agent > /dev/null; then
    eval "$(ssh-agent -s)"
fi

# Add the SSH key automatically if not already added
if ! ssh-add -l | grep -q "$(ssh-keygen -lf /home/tbe/.ssh/id_ed25519.pub 2>/dev/null | awk '{print $2}')"; then
    ssh-add /home/tbe/.ssh/id_ed25519
fi

# gpt agent
export GPG_TTY=$(tty)

alias rg='rg --no-ignore-vcs'

source /home/$USER/machine_specific.sh
