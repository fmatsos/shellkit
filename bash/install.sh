#!/usr/bin/env bash
# Puts a shellkit block at the top of ~/.bashrc (the rest of the file is yours) and generates
# the completions bash-completion lazy-loads (one file per command, loaded on the first
# <Tab>). Re-runnable: run it again after upgrading codex/composer/symfony/npm, or to refresh
# the block.
set -eu
dir=$(cd "$(dirname "$0")" && pwd)

# ~/.bashrc is a file of your own: a block loads shellkit, the rest is yours (never versioned).
if [[ -L ~/.bashrc ]]; then   # the former symlink: nothing of yours in it, unless it led elsewhere
  if [[ ~/.bashrc -ef $dir/bashrc ]]; then rm ~/.bashrc; else cp -L ~/.bashrc ~/.bashrc.tmp && mv -f ~/.bashrc.tmp ~/.bashrc; fi
elif [[ -s ~/.bashrc ]] && ! grep -qxF '# >>> shellkit >>>' ~/.bashrc && [[ ! -e ~/.bashrc.pre-config ]]; then
  cp -p ~/.bashrc ~/.bashrc.pre-config; echo "~/.bashrc saved as ~/.bashrc.pre-config"
fi
home='$HOME'; shown=${dir/#"$HOME"/$home}   # the block says $HOME, not this machine's path
"$dir/../shell/rc-block.sh" ~/.bashrc shellkit <<EOB
# Managed by shellkit (bash/install.sh): rewritten at each run. Your own lines go outside this block.
[[ -r "$shown/bashrc" ]] && . "$shown/bashrc"
EOB
echo "~/.bashrc: shellkit block -> $dir/bashrc"

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
