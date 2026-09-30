# The installed zsh (zsh/install.sh), as a user gets it: `zsh -i .github/smoke.zsh`.
# CI runs it; locally, only in a throwaway HOME (it adds a plugin).
fail=0 here=${0:A:h}
ok() { [[ $1 == 0 ]] && print "ok   $2" || { print "FAIL $2${3:+: $3}"; fail=1; } }

[[ -o interactive && $(whence -w shkit) == 'shkit: function' ]]; ok $? "zshrc loaded: shkit"
alias ll gs >/dev/null && ll / >/dev/null; ok $? "aliases (shell/aliases.sh), ls flags"
[[ $LC_CTYPE$LC_ALL$LANG == *[Uu][Tt][Ff]*8* ]]; ok $? "a UTF-8 locale" "${LC_CTYPE-}|${LANG-}"

t=${$(mktemp -d):A}
git init -q -b main $t/repo && cd $t/repo && git config user.email t@t && git config user.name t &&
  print a >f && git add f && git commit -qm init
_prompt_precmd >/dev/null; p=${(%)PROMPT}
[[ $p == *repo* && $p == *main* ]]; ok $? "prompt: directory and branch" "$p"
print -r -- ${(qqqq):-$t/repo} >>| ~/.cache/zsh/recent-dirs   # >>|: noclobber; what `cd` records (not from a script)
cd ~; [[ $(_zshrc_jump_target repo; print $REPLY) == $t/repo ]]; ok $? "a directory's name alone jumps to it"

command cp -R $here/../zsh/plugin/example $t/ex && git init -q -b main $t/ex &&
  git -C $t/ex config user.email t@t && git -C $t/ex config user.name t && git -C $t/ex add -A && git -C $t/ex commit -qm ex
shkit plugin add -y $t/ex >/dev/null && shkit set theme example/mono >/dev/null && shkit set format '{hello} {dir}' >/dev/null
cd $t/repo; _prompt_precmd >/dev/null; p=${(%)PROMPT}
[[ $p == *☺* && $p == *$'\e[38;5;42m'* ]]; ok $? "plugin: add (jq, git), theme, block rendered" "$p"
shkit unset format >/dev/null; shkit unset theme >/dev/null; shkit plugin remove example >/dev/null
d=$(shkit doctor 2>&1); ok $? "shkit doctor: no failure" "${(M)${(f)d}:#FAIL*}"

exit $fail
