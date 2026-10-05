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

# Projects: scan only on demand. SHKIT_PROJECT_ROOTS=(src-root sandbox-root).
_shkit_project_paths() (
    # Unmatched globs stay literal in both shells; -d below skips them.
    [ -z "${ZSH_VERSION:-}" ] || setopt NONOMATCH
    local root d
    local -a roots
    if [ "${SHKIT_PROJECT_ROOTS+x}" ]; then
        roots=("${SHKIT_PROJECT_ROOTS[@]}")
    else
        roots=("$HOME/src" "$HOME/sandbox")
    fi
    set -- "${roots[@]}"
    root=${1:-}
    if [ -d "$root" ]; then
        for d in "${root%/}"/*/*/*; do
            [ ! -d "$d" ] || printf '%s\n' "$d"
        done
    fi
    root=${2:-}
    if [ -d "$root" ]; then
        for d in "${root%/}"/*; do
            [ ! -d "$d" ] || printf '%s\n' "$d"
        done
    fi
)

p() {
    local d name
    local -a exact=() partial=()
    [ "$#" -le 1 ] || { printf 'usage: p [name | owner/name | host/owner/name]\n' >&2; return 1; }
    if [ "$#" -eq 0 ]; then
        printf 'usage: p name | owner/name | host/owner/name\n'
        return 0
    fi
    name=$1
    while IFS= read -r d; do
        if [[ "$d" == */"$name" ]]; then
            exact+=("$d")
        elif [[ "$d" == *"$name"* ]]; then
            partial+=("$d")
        fi
    done < <(_shkit_project_paths)
    [ "${#exact[@]}" -gt 0 ] || exact=("${partial[@]}")
    case ${#exact[@]} in
        0) printf 'p: not found: %s\n' "$name" >&2; return 1 ;;
        1) for d in "${exact[@]}"; do builtin cd -- "$d" || return; done ;;
        *) printf 'p: ambiguous: %s\n' "$name" >&2
           printf '  %s\n' "${exact[@]}" >&2; return 1 ;;
    esac
}

# Shortest unique suffix: name, owner/name, then host/owner/name if needed.
_shkit_project_completions() {
    local d other suffix parent count
    local -a dirs=()
    while IFS= read -r d; do dirs+=("$d"); done < <(_shkit_project_paths)
    for d in "${dirs[@]}"; do
        suffix=${d##*/} parent=${d%/*}
        while :; do
            count=0
            for other in "${dirs[@]}"; do
                [[ "$other" != */"$suffix" ]] || count=$((count + 1))
            done
            [ "$count" -gt 1 ] && [ -n "$parent" ] || break
            suffix=${parent##*/}/$suffix parent=${parent%/*}
        done
        if [[ "$suffix" == "${1:-}"* || "$suffix" == */"${1:-}"* ]]; then
            printf '%s\n' "$suffix"
        fi
    done
}
