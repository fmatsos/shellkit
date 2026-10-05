#!/usr/bin/env bash
# Self-check in both shells: bash shell/projects.check.sh; zsh shell/projects.check.sh.
# Test status assertions and settings consumed by sourced functions.
# shellcheck disable=SC2319,SC2034
here=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd)
t=$(mktemp -d); trap 'command rm -rf -- "$t"' EXIT
export HOME=$t/home
unset SHKIT_PROJECT_ROOTS
set -o noclobber
# shellcheck source=shell/aliases.sh
. "$here/aliases.sh"
fail=0
ok() { if [ "$1" = 0 ]; then echo "ok   $2"; else echo "FAIL $2"; fail=1; fi; }

command mkdir -p "$HOME/src/github.com/alice/tool" "$HOME/src/github.com/bob/tool" \
    "$HOME/src/github.com/alice/widget" "$HOME/sandbox/scratch pad" \
    "$HOME/src/shallow" "$HOME/src/github.com/alice/widget/nested"
cd "$HOME" || exit 1
p widget && [ "$PWD" = "$HOME/src/github.com/alice/widget" ]; ok $? 'unique repo name'
p 'scratch pad' && [ "$PWD" = "$HOME/sandbox/scratch pad" ]; ok $? 'loose folder with spaces'
before=$PWD
p tool >| "$t/out" 2>&1; result=$?
[ "$result" = 1 ] && [ "$PWD" = "$before" ] &&
    command grep -q 'alice/tool' "$t/out" && command grep -q 'bob/tool' "$t/out"
ok $? 'ambiguous name lists both paths and stays put'
p alice/tool && [ "$PWD" = "$HOME/src/github.com/alice/tool" ]; ok $? 'owner/name suffix'
p github.com/bob/tool && [ "$PWD" = "$HOME/src/github.com/bob/tool" ]; ok $? 'host/owner/name suffix'
p idg && [ "$PWD" = "$HOME/src/github.com/alice/widget" ]; ok $? 'unique substring fallback'
command mkdir -p "$HOME/sandbox/widget-copy"
p widget && [ "$PWD" = "$HOME/src/github.com/alice/widget" ]; ok $? 'exact match wins over substring'
p too >| "$t/out" 2>&1; [ "$?" = 1 ]; ok $? 'ambiguous substring fails'
p absent >| "$t/out" 2>&1; [ "$?" = 1 ] && command grep -q 'not found' "$t/out"; ok $? 'not found'
p shallow >| "$t/out" 2>&1; [ "$?" = 1 ]; ok $? 'src depth is exactly three'
p nested >| "$t/out" 2>&1; [ "$?" = 1 ]; ok $? 'does not recurse inside a project'
p >| "$t/out" && command grep -q usage "$t/out"; ok $? 'no argument shows usage'
_shkit_project_completions tool >| "$t/out"
command grep -qx 'alice/tool' "$t/out" && command grep -qx 'bob/tool' "$t/out" &&
    ! command grep -qx tool "$t/out"; ok $? 'completion disambiguates names even with a name prefix'
command mkdir -p "$HOME/src/git.example/alice/tool"
_shkit_project_completions alice/ >| "$t/out"
command grep -qx 'github.com/alice/tool' "$t/out" && command grep -qx 'git.example/alice/tool' "$t/out"
ok $? 'completion disambiguates owners across hosts'
_shkit_project_completions 'scratch' >| "$t/out"
command grep -qx 'scratch pad' "$t/out"; ok $? 'completion preserves spaces'
command mkdir -p "$HOME/other repos/github.com/alice/custom"
SHKIT_PROJECT_ROOTS=("$HOME/other repos" "$HOME/missing")
p custom && [ "$PWD" = "$HOME/other repos/github.com/alice/custom" ]; ok $? 'configured roots, missing sandbox'
SHKIT_PROJECT_ROOTS=("$HOME/missing" "$HOME/sandbox")
p 'scratch pad' && [ "$PWD" = "$HOME/sandbox/scratch pad" ]; ok $? 'missing src root is skipped'
SHKIT_PROJECT_ROOTS=("$HOME/missing" "$HOME/also missing")
[ -z "$(_shkit_project_paths 2>&1)" ]; ok $? 'missing roots are silent'
p widget >| "$t/out" 2>&1; [ "$?" = 1 ]; ok $? 'missing roots return not found'

exit "$fail"
