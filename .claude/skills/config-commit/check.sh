#!/usr/bin/env bash
# Everything that must pass before a commit of this repo: shell syntax, the
# prompt self-check, the zsh startup budget, and no secret in the index.
#   .claude/skills/config-commit/check.sh      (run after `git add`; exit 1 = don't commit)
# Secret values are compared, never printed.
set -u
C=$(git -C "$(dirname "$0")" rev-parse --show-toplevel) || exit 1
fail=0
ko() { echo "FAIL $*"; fail=1; }

for f in "$C"/zsh/zshrc "$C"/zsh/zshenv "$C"/zsh/*.zsh "$C"/zsh/plugin/example/*/*.zsh "$C"/.github/*.zsh; do zsh -n "$f" || ko "zsh syntax: ${f#$C/}"; done
for f in "$C"/bash/bashrc "$C"/bash/*.sh "$C"/shell/*.sh "$C"/zsh/install.sh "$C"/.github/*.bash; do bash -n "$f" || ko "bash syntax: ${f#$C/}"; done

out=$(zsh "$C/zsh/prompt.check.zsh" 2>&1) || ko "prompt self-check:"$'\n'"$(grep -v '^ok' <<<"$out")"
echo "prompt self-check: $(grep -c '^ok' <<<"$out") ok"

for shell in bash zsh; do
  out=$("$shell" "$C/shell/projects.check.sh" 2>&1) || ko "$shell projects self-check:"$'\n'"$out"
  echo "$shell projects self-check: $(grep -c '^ok' <<<"$out") ok"
done

# Startup of this working tree's zshrc (ZDOTDIR, not whatever ~/.zshrc is): no
# output on stderr, and best of 5 (the first run warms the caches) within 60 ms,
# usual ~35 ms. Timed by zsh: BSD date (macOS) has no %N.
export ZDOTDIR=$(mktemp -d) SHKIT_AUTO_UPDATE=false   # timing, not a fetch of this clone
ln -s "$C/zsh/zshenv" "$ZDOTDIR/.zshenv" && ln -s "$C/zsh/zshrc" "$ZDOTDIR/.zshrc"
err=$(zsh -ic exit 2>&1 </dev/null >/dev/null) && [[ -z $err ]] || ko "zsh startup prints:"$'\n'"$err"
best=$(zsh -fc 'zmodload zsh/datetime; integer b=999999 ms
  repeat 5 { s=$EPOCHREALTIME; zsh -ic exit </dev/null >/dev/null 2>&1; (( ms = (EPOCHREALTIME - s) * 1000, b = ms < b ? ms : b )) }
  print $b')
rm -r "$ZDOTDIR"; unset ZDOTDIR
if (( best <= 60 )); then echo "zsh startup: ${best} ms"
elif [[ -n ${CI:-} ]]; then echo "zsh startup: ${best} ms (budget 60 ms, not enforced on a shared CI runner)"
else ko "zsh startup: ${best} ms (budget 60 ms)"
fi

# Secrets: exact values from secrets.sh (and the older ~/.config/shell and
# ~/.secrets.local, so a machine not migrated yet is still scanned), then common token shapes.
for s in "${XDG_CONFIG_HOME:-$HOME/.config}/shkit/secrets.sh" "${XDG_CONFIG_HOME:-$HOME/.config}/shell/secrets.sh" ~/.secrets.local; do
  [[ -r $s ]] || continue
  [[ -n $(find "$s" -perm 600) ]] || ko "$s is not chmod 600"   # find: stat -c is GNU only
  while IFS= read -r v; do
    [[ ${#v} -ge 8 ]] && git -C "$C" grep -qF --cached -- "$v" && ko "a value of $s is in the index"
  done < <(sed -nE "s/^export [A-Z_]+=['\"]?([^'\"]*)['\"]?$/\1/p" "$s")
done
git -C "$C" grep -nE --cached \
  'xox[abpcdr]-[0-9A-Za-z-]{10,}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{15,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}' &&
  ko "token-shaped string in the index (above)"
(( fail )) || echo "secrets: clean"

exit $fail
