#!/usr/bin/env bash
# Try shellkit without installing it: a zsh on this repository's zshrc, whose settings,
# history and caches live in a temporary directory, deleted on exit. ~/.zshrc, your
# history and ~/.config are left alone.
#   zsh/try.sh               an interactive shell (exit to leave)
#   zsh/try.sh -c 'CMD'      one command in it, e.g. 'shkit doctor'
set -eu
dir=$(cd "$(dirname "$0")" && pwd)
t=$(mktemp -d "${TMPDIR:-/tmp}/shellkit-try.XXXXXX")
trap 'rm -rf "$t"' EXIT
printf '. %q\n' "$dir/zshenv" >"$t/.zshenv"
printf '. %q\nHISTFILE=%q\n' "$dir/zshrc" "$t/history" >"$t/.zshrc"   # zsh reads history after zshrc
[ $# -gt 0 ] || echo "shellkit, in this shell only: exit to leave, nothing is kept" >&2
ZDOTDIR=$t SHELL_LOCAL_DIR=$t/shkit XDG_CACHE_HOME=$t/cache SHKIT_AUTO_UPDATE=false SHKIT_TRY=1 zsh -i "$@"
