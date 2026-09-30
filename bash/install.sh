#!/usr/bin/env bash
# Links ~/.bashrc to this repo and generates the completions bash-completion
# lazy-loads (one file per command, loaded on the first <Tab>). Re-runnable:
# run it again after upgrading codex/composer/symfony/npm.
set -eu
dir=$(cd "$(dirname "$0")" && pwd)

if [[ -e ~/.bashrc && ! -L ~/.bashrc ]]; then
  mv ~/.bashrc ~/.bashrc.pre-config
  echo "~/.bashrc saved as ~/.bashrc.pre-config"
fi
ln -sfn "$dir/bashrc" ~/.bashrc
echo "~/.bashrc -> $dir/bashrc"

comp=${XDG_DATA_HOME:-$HOME/.local/share}/bash-completion/completions
mkdir -p "$comp"
gen() { # CMD... -> $comp/CMD (no declare -A: macOS runs this with bash 3.2)
  command -v "$1" >/dev/null || return 0
  "$@" >"$comp/$1.tmp" 2>/dev/null && mv -f "$comp/$1.tmp" "$comp/$1" && echo "completion: $1" ||
    { rm -f "$comp/$1.tmp"; echo "completion: $1 failed, skipped" >&2; }
}
gen codex completion bash
gen composer completion bash
gen symfony completion bash
gen npm completion

# macOS terminals open login shells, which read ~/.bash_profile, not ~/.bashrc.
if [[ $(uname) == Darwin && ! -e ~/.bash_profile ]]; then
  echo '[[ -r ~/.bashrc ]] && . ~/.bashrc' >~/.bash_profile
  echo "~/.bash_profile created (sources ~/.bashrc)"
fi

"$dir/../shell/install-local.sh"   # ~/.config/shkit
