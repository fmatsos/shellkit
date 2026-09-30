# shellcheck shell=bash
# Aliases and helper functions shared by bash and zsh (keep it portable:
# no bash-only or zsh-only syntax here).

# What oh-my-bash used to wrap, kept so muscle memory keeps working.
# GNU ls colors with --color; BSD ls (macOS) needs CLICOLOR, even with --color=auto.
export CLICOLOR=1
ls --color=auto -d / >/dev/null 2>&1 && alias ls='ls --color=auto'
alias ll='ls -lAFh'
alias l='ls -lha'
alias la='ls -lhA'
alias grep='grep --color=auto --exclude-dir={.bzr,CVS,.git,.hg,.svn}'
alias cp='cp -iv'
alias mv='mv -iv'
alias mkdir='mkdir -pv'
case $(nano --version 2>/dev/null) in *GNU*) alias nano='nano -W' ;; esac   # macOS's nano may be pico
alias less='less -FSRXc'
alias wget='wget -c'

# Docker
dstop() { set -- $(docker ps -q); [ $# -eq 0 ] || docker stop "$@"; }   # no xargs -r (GNU only)

# Git
alias gs='git switch'
alias gpf='git push --force-with-lease'
alias gclean='git-cleanup --verbose'

# Symfony
rmc() {
    [[ -f bin/console && -f composer.json ]] || {
        echo "Erreur : ce répertoire n'est pas un projet Symfony." >&2
        return 1
    }

    sudo find . \
        \( -path '*/var/cache' -o -path '*/var/*/cache' \) \
        -type d \
        -exec rm -rf {} +
}

rml() {
    [[ -f bin/console && -f composer.json ]] || {
        echo "Erreur : ce répertoire n'est pas un projet Symfony." >&2
        return 1
    }

    sudo find . \
        \( -path '*/var/log' -o -path '*/var/*/log' \) \
        -type d \
        -exec rm -rf {} +
}
