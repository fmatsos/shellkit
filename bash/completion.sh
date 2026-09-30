# shellcheck shell=bash
# Bash-only: git completion for the `gs` alias and the `git task` alias.

# Charge la complétion Git si elle n'est pas déjà disponible.
if ! declare -F __git_main >/dev/null 2>&1; then
    for git_completion in \
        /usr/share/bash-completion/completions/git \
        /etc/bash_completion.d/git \
        /opt/homebrew/etc/bash_completion.d/git-completion.bash \
        /usr/local/etc/bash_completion.d/git-completion.bash \
        /Library/Developer/CommandLineTools/usr/share/git-core/git-completion.bash
    do
        if [ -r "$git_completion" ]; then
            source "$git_completion"
            break
        fi
    done
fi

_git_task() {
    local query="${cur,,}"
    local branch
    local short_name
    local selected
    local -a matches=()

    COMPREPLY=()

    # git task <argument>
    [ "$cword" -eq 2 ] || return 0
    [ -n "$cur" ] || return 0

    while IFS= read -r branch; do
        short_name="${branch##*/}"

        # Accepte :
        #   SHOP-5
        #   feature/SHOP-5
        if [[ "${short_name,,}" == "${query}"* ]] ||
           [[ "${branch,,}" == "${query}"* ]]; then
            matches+=("$branch")
        fi
    done < <(
        git for-each-ref \
            --format='%(refname:short)' \
            refs/heads \
            2>/dev/null
    )

    case "${#matches[@]}" in
        0)
            return 0
            ;;

        1)
            COMPREPLY=("${matches[0]}")
            return 0
            ;;
    esac

    # Plusieurs correspondances : sélection interactive.
    if command -v fzf >/dev/null 2>&1; then
        selected="$(
            printf '%s\n' "${matches[@]}" |
            fzf \
                --height=40% \
                --reverse \
                --border \
                --prompt="Branche $cur > "
        )" || return 0

        [ -n "$selected" ] && COMPREPLY=("$selected")
        return 0
    fi

    # Sans fzf, Bash affiche sa liste de complétion native.
    COMPREPLY=("${matches[@]}")
}

declare -F __git_complete >/dev/null && __git_complete gs _git_switch
