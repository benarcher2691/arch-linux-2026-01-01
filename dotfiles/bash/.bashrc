# ~/.bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# History
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoreboth:erasedups
shopt -s histappend

# Check window size after each command
shopt -s checkwinsize

# Prompt
PS1='\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '

# Aliases
alias ls='ls --color=auto'
alias ll='ls -lah'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias diff='diff --color=auto'

alias ..='cd ..'
alias ...='cd ../..'

# Modern replacements (if installed)
# command -v yazi &> /dev/null && alias y='yazi'
# command -v nvim &> /dev/null && alias vim='nvim'

# Environment
export EDITOR=vim
export VISUAL=vim

# Path
export PATH="$HOME/.local/bin:$PATH"

# NVM (Node Version Manager)
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"

# SDKMAN
export SDKMAN_DIR="$HOME/.sdkman"
[[ -s "$HOME/.sdkman/bin/sdkman-init.sh" ]] && source "$HOME/.sdkman/bin/sdkman-init.sh"

# Wayland
export MOZ_ENABLE_WAYLAND=1
