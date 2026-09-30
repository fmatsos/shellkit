#!/usr/bin/env bash
# Creates ~/.config/shkit (the files for this machine only, never in the repo) and
# moves the older files into it: ~/.config/shell (before shellkit), then the pre-2026-09
# dotfiles. Called by zsh/install.sh and bash/install.sh.
set -eu
d=${XDG_CONFIG_HOME:-$HOME/.config}/shkit
old=${d%/*}/shell
if [[ -d $old && ! -L $old ]] && ! rmdir "$old" 2>/dev/null; then   # empty: just drop it
  if [[ -e $d ]]; then echo "note: $old left in place, $d already exists: merge by hand" >&2
  else mv "$old" "$d" && echo "$old -> $d"
  fi
fi
mkdir -p "$d/prompt.d" && chmod 700 "$d"
for m in settings.local:settings.sh secrets.local:secrets.sh theme.local:theme.zsh prompt.d:prompt.d; do
  old=~/.${m%%:*} new=$d/${m#*:}
  [[ -e $old ]] || continue
  if [[ $new == */prompt.d ]]; then mv -n "$old"/* "$new"/ 2>/dev/null || true; rmdir "$old" 2>/dev/null || true
  elif [[ ! -e $new ]]; then mv "$old" "$new"
  fi
  [[ -e $old ]] && echo "note: $old left in place, $new already exists: merge by hand" >&2 || echo "$old -> $new"
done
[[ ! -e $d/secrets.sh ]] || chmod 600 "$d/secrets.sh"
# shellkit 1.0 named the prompt settings PROMPT_*, 1.1 SHKIT_* (the old names are still read)
for f in "$d/settings.sh" "$d/theme.zsh" "$d"/projects/*.zsh; do
  # bash's and zsh's own (PROMPT_COMMAND, PROMPT_EOL_MARK…) set aside first: never renamed
  keep='s/PROMPT_(COMMAND|DIRTRIM|EOL_MARK)=/@SHKIT_KEEP@\1=/g'
  [[ -f $f ]] && sed -E "$keep" "$f" | grep -Eq '(^|[[:space:]#])PROMPT_[A-Z0-9_]+=' || continue   # commented-out examples too
  cp -p "$f" "$f.bak"
  sed -E -e "$keep" -e 's/^PROMPT_([A-Z0-9_]+=)/SHKIT_\1/' -e 's/([[:space:]#])PROMPT_([A-Z0-9_]+=)/\1SHKIT_\2/g' \
    -e 's/@SHKIT_KEEP@/PROMPT_/g' "$f" > "$f.new" && cat "$f.new" > "$f" && rm "$f.new"   # cat: keeps the mode
  echo "$f: PROMPT_* -> SHKIT_* (before: $f.bak)"
done
for f in settings.sh secrets.sh; do
  [[ -e $d/$f ]] || echo "note: $d/$f not found (optional)"
done
