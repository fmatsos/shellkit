#!/usr/bin/env bash
# Links ~/.zshrc and ~/.zshenv to this repo, generates completions, and imports the bash
# history once (only when ~/.zsh_history does not exist yet). Re-runnable:
# run it again after upgrading codex/symfony/npm/composer.
set -eu
dir=$(cd "$(dirname "$0")" && pwd)

for f in zshrc zshenv; do
  if [[ -e ~/.$f && ! -L ~/.$f ]]; then mv ~/.$f ~/.$f.pre-config; echo "~/.$f saved as ~/.$f.pre-config"; fi
  ln -sfn "$dir/$f" ~/.$f
  echo "~/.$f -> $dir/$f"
done

"$dir/../shell/install-local.sh"   # ~/.config/shkit (settings, secrets, theme, prompt blocks)

# Completions: zsh-native where the tool ships one, bash-style otherwise
# (loaded through bashcompinit by zshrc).
data=${XDG_DATA_HOME:-$HOME/.local/share}
mkdir -p "$data/zsh/site-functions" "$data/bash-completion/completions"
gen() { # OUTPUT CMD...
  command -v "$2" >/dev/null || return 0
  if "${@:2}" >"$1.tmp" 2>/dev/null && [[ -s $1.tmp ]]; then mv -f "$1.tmp" "$1"; echo "completion: ${1##*/}"
  else rm -f "$1.tmp"; echo "completion: ${1##*/} failed, skipped" >&2; fi
}
gen "$data/zsh/site-functions/_codex" codex completion zsh
gen "$data/zsh/site-functions/_symfony" symfony completion zsh
gen "$data/zsh/npm-completion.zsh" npm completion
gen "$data/bash-completion/completions/composer" composer completion bash
rm -f ~/.cache/zsh/zcompdump   # new completions: rebuild the dump
# Homebrew's zsh dirs are group-writable: compinit would ask about "insecure directories".
for b in /opt/homebrew /usr/local; do
  [[ -d $b/share/zsh && -x $b/bin/brew ]] && chmod -R go-w "$b/share/zsh" && echo "compaudit: $b/share/zsh made go-w"
done

# Bash history -> zsh extended history (": <epoch>:0;<command>"), once.
# Bash entries start with a "#<epoch>" line when timestamps were on; multi-line
# commands (lithist) continue until the next one. Older, untimed lines keep the
# first known timestamp so they stay in order.
if [[ ! -e ~/.zsh_history && -r ~/.bash_history ]]; then
  awk '
    function flush() { if (cmd != "") printf ": %d:0;%s\n", ts, cmd; cmd = "" }
    /^#[0-9]+$/ { flush(); ts = substr($0, 2); timed = 1; next }   # no {10}: older BSD awk (macOS)
    {
      if (!timed) { flush(); cmd = $0; next }       # untimed: one line, one entry
      cmd = (cmd == "") ? $0 : cmd "\\\n" $0        # zsh continuation: backslash-newline
    }
    END { flush() }
  ' ~/.bash_history | awk -v first="$(grep -m1 -E '^#[0-9]+$' ~/.bash_history | tr -d '#')" \
    '{ if ($0 ~ /^: 0:0;/) sub(/^: 0:/, ": " (first ? first : 0) ":") ; print }' >~/.zsh_history
  chmod 600 ~/.zsh_history
  echo "history: $(grep -c '^: [0-9]*:0;' ~/.zsh_history) entries imported from ~/.bash_history"
fi
