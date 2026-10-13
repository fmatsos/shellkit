#!/usr/bin/env bash
# Self-check of rc-block.sh: bash shell/rc-block.check.sh
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
t=$(mktemp -d); trap 'rm -rf -- "$t"' EXIT
fail=0
ok() { if [ "$1" = 0 ]; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi; }
rc() { "$here/rc-block.sh" "$@"; }

echo 'one' | rc "$t/new" a; [ "$(cat "$t/new")" = "$(printf '# >>> a >>>\none\n# <<< a <<<')" ]; ok $? 'creates a missing file'

printf 'export X=1\nalias l=ls\n' >"$t/rc"; chmod 640 "$t/rc"
echo 'one' | rc "$t/rc" a
[ "$(sed -n 1,4p "$t/rc")" = "$(printf '# >>> a >>>\none\n# <<< a <<<\n')" ] && grep -qx 'alias l=ls' "$t/rc"; ok $? 'inserts at the top, keeps the rest'
cp "$t/rc" "$t/before"; echo 'one' | rc "$t/rc" a; cmp -s "$t/rc" "$t/before"; ok $? 'same body: unchanged'
printf 'two\nlines\n' | rc "$t/rc" a
[ "$(grep -c '>>> a >>>' "$t/rc")" = 1 ] && grep -qx lines "$t/rc" && ! grep -qx one "$t/rc" && grep -qx 'export X=1' "$t/rc"; ok $? 'rewrites in place'
echo 'dot' | rc "$t/rc" b
[ "$(sed -n 1p "$t/rc")" = '# >>> b >>>' ]; ok $? 'a second block goes on top (the caller orders them)'
[ "$(stat -c %a "$t/rc" 2>/dev/null || stat -f %Lp "$t/rc")" = 640 ]; ok $? 'keeps the file mode'
echo 'bs \n $HOME `x`' | rc "$t/rc" a; grep -qxF 'bs \n $HOME `x`' "$t/rc"; ok $? 'body is not interpreted'
exit $fail
