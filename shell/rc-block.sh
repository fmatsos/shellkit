#!/usr/bin/env bash
# rc-block.sh FILE NAME  (the block's body on stdin)
# Puts a block, `# >>> NAME >>>` … `# <<< NAME <<<`, at the top of FILE (created when missing),
# or rewrites it in place when FILE already has it. Everything outside the block is kept as is.
# Run by zsh/install.sh and bash/install.sh; bash 3.2 and POSIX awk (macOS).
set -eu
f=$1 n=$2
b="# >>> $n >>>" e="# <<< $n <<<"
BODY=$(cat); export BODY
t=$(mktemp "$f.XXXXXX")
trap 'rm -f "$t"' EXIT
if [[ -e $f ]] && grep -qxF "$b" "$f"; then
  awk -v b="$b" -v e="$e" '
    $0 == b { skip = 1; print b; print ENVIRON["BODY"]; print e; next }
    skip && $0 == e { skip = 0; next }
    !skip { print }' "$f" >"$t"
else
  { printf '%s\n%s\n%s\n' "$b" "$BODY" "$e"; [[ -s $f ]] && { echo; cat "$f"; }; } >"$t"
fi
cat "$t" >"$f"   # not mv: keeps the file's mode and owner
