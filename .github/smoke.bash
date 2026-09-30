# The installed bash (bash/install.sh), as a user gets it: `bash -i .github/smoke.bash`.
fail=0
ok() { [[ $1 == 0 ]] && echo "ok   $2" || { echo "FAIL $2${3:+: $3}"; fail=1; }; }

[[ $- == *i* ]] && alias ll gs >/dev/null && ll / >/dev/null; ok $? "bashrc loaded: aliases, ls flags"
shopt -q autocd globstar && [[ -o noclobber ]]; ok $? "options: autocd, globstar, noclobber"

t=$(mktemp -d)
git init -q -b main "$t/repo" && cd "$t/repo" && git config user.email t@t && git config user.name t &&
  echo a >f && git add f && git commit -qm init
eval "$PROMPT_COMMAND"
[[ ${PS1@P} == *main* ]]; ok $? "prompt: the branch" "${PS1@P}"

exit $fail
