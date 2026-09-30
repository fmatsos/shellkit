#!/usr/bin/env zsh
# Self-check for prompt.zsh (local segments + async watcher, no network):
#   zsh zsh/prompt.check.zsh
setopt NO_CLOBBER   # as in zshrc: the prompt must write its cache with >|
setopt EXTENDED_GLOB   # for the escape-stripping patterns below (the prompt itself doesn't need it)
unset LC_ALL; export LC_CTYPE=${${OSTYPE:#darwin*}:+C.}UTF-8   # as zshrc with no locale (CI): the icons need UTF-8
t=${$(mktemp -d):A}; trap 'rm -rf $t' EXIT   # :A = real path: macOS's /var is /private/var, git answers that one
export HOME=$t/home XDG_CONFIG_HOME=$t/home/.config XDG_RUNTIME_DIR=$t/run GIT_CONFIG_GLOBAL=/dev/null
mkdir -p $HOME/.claude/sessions $XDG_RUNTIME_DIR
alias mkdir='mkdir -pv' mv='mv -iv' rm='rm -iv' rmdir='rmdir -v'   # shell/aliases.sh wraps these
PROMPT_FORMAT='{dir} · {git} · {mr} · {agents}' PROMPT_RIGHT_FORMAT='{quota}' PROMPT_COLOR_ACCENT='38;5;33' PROMPT_ICON_DIR= PROMPT_ICON_REFRESH='%↻'
PROMPT_SHOW_MR=false PROMPT_AUTO_FETCH=false PROMPT_TITLE_SPINNER=false SHKIT_AUTO_UPDATE=false   # no job on the real clone
command mkdir -p $XDG_CONFIG_HOME/shkit/prompt.d; cat >$XDG_CONFIG_HOME/shkit/prompt.d/hello.zsh <<'EOS'   # a local block: its own color, icon, and an override
: ${PROMPT_COLOR_HELLO:='38;5;42'} ${PROMPT_ICON_HELLO=☺}
function _prompt_seg_hello { _prompt_esc "hi %$USER"; segs+="${_c_hello}${_i_hello} ${REPLY}${_c_reset}"; }
_builtin_docker=$functions[_prompt_seg_docker]; function _prompt_seg_docker { segs+=mine; }
EOS
fail=0
here=${0:A:h}; source $here/prompt.zsh
unalias mkdir mv rm rmdir   # aliases only matter while the prompt is parsed
PROMPT_FORMAT='{docker}' _prompt_render; [[ ${(%)PROMPT} == mine* ]] && print "ok   local block overrides a built-in" || { print "FAIL override"; fail=1; }
functions[_prompt_seg_docker]=$_builtin_docker   # the built-in again, for the checks below

render() { _prompt_status=${1:-0}; _prompt_render; raw=${(%)PROMPT}; out=${raw//$'\e['[0-9;]#m/}; out=${out//$'\e]8;;'[^$'\e']#$'\e\\'/}; }
check() { [[ $out == *"$1"* ]] && print "ok   $2" || { print "FAIL $2: '$1' not in: $out"; fail=1; } }

cd $t && git init -q -b main repo && cd repo && git config user.email t@t && git config user.name t
print 'a\nb' >f && git add f && git commit -qm init
render; check " main" "branch"
print 'a\nc\nd' >| f; render; check "main ·  1 +2 −1" "dirty files + diff stat"

mkdir .git/rebase-merge && print 2 >.git/rebase-merge/msgnum && print 5 >.git/rebase-merge/end && print refs/heads/SHOP-1 >.git/rebase-merge/head-name
render; check "SHOP-1" "branch name during rebase"; check "rebase 2/5" "rebase progress"
rm -r .git/rebase-merge

git switch -qc '$(touch${IFS}pwned)%F{red}'; render
[[ ! -e pwned ]] && print "ok   branch name is not executed" || { print "FAIL branch name executed"; fail=1; }
check '$(touch${IFS}pwned)%F{red}' "branch name printed verbatim (no \$(), no %-escape)"

[[ -r /proc/$$/stat ]] && st=$(</proc/$$/stat) && st=(${=${st##*\) }})   # no /proc on macOS: liveness only
print -n "{\"pid\":$$,\"procStart\":\"$st[20]\",\"status\":\"busy\"}" >$HOME/.claude/sessions/$$.json
print -n '{"pid":1,"procStart":"42","status":"busy"}' >$HOME/.claude/sessions/1.json   # pid alive, wrong start time
render; check "✻ 1 agent · 1 busy" "agents: live counted, reused pid ignored"
print -n '{"pid":999999}' >$HOME/.claude/sessions/999999.json   # dead
_prompt_proc=$t/noproc; render; _prompt_proc=/proc; command rm $HOME/.claude/sessions/{1,999999}.json
check "✻ 1 agent · 1 busy" "agents without /proc (macOS): alive pid counted, dead one not"
print -n '{"pid":1,"procStart":"42","status":"busy"}' >$HOME/.claude/sessions/1.json

git switch -q main
_prompt_key "mr$PWD/.git@main"; print -r -- "$EPOCHSECONDS"$'\n2741\thttps://gitlab.example/mr/2741\t1\topened\tfailed' >$REPLY
PROMPT_SHOW_MR=true; render; PROMPT_SHOW_MR=false
check "!2741  draft  ✗" "MR from cache: number, draft, failed CI"
[[ $raw == *$'\e]8;;https://gitlab.example/mr/2741'* ]] && print "ok   MR is an OSC 8 link" || { print "FAIL MR link"; fail=1; }

mkdir $t/bin; cat >$t/bin/docker <<'EOS'   # stub: `timeout` runs a binary, not a function
#!/bin/sh
printf '%s\t%s\t%s\t%s\t%s\n' \
  lmm '' running 'Up 2 hours' nginx \
  lmm '' running 'Up 2 hours (unhealthy)' mysql8 \
  lmm '' exited 'Exited (1) 3 minutes ago' app \
  lmm True exited 'Exited (1) 1 hour ago' lmm-run-1 \
  lmm '' exited 'Exited (0) 1 hour ago' minio-init \
  npu '' exited 'Exited (137) 5 days ago' npu-ovms
EOS
chmod +x $t/bin/docker; path=($t/bin $path)
_prompt_job_docker $t/dk; _prompt_job_docker $t/dk; { read -r _; IFS= read -r dk } <$t/dk
[[ $dk == $'2\tmysql8,app' ]] && print "ok   docker: unhealthy + crashed in an up stack; one-off, exit 0, stopped stack ignored" || { print "FAIL docker: '$dk'"; fail=1; }
( unhash timeout gtimeout 2>/dev/null; _prompt_job_docker $t/dk2; perl -e 'alarm shift; exec @ARGV or exit 127' -- 1 sleep 3; print $? ) >$t/pl 2>&1
[[ $(<$t/dk2) == *$'\n2\tmysql8,app' && $(<$t/pl) == 142 ]] && print "ok   no timeout (macOS): perl runs the job, and kills it at the deadline" || { print "FAIL perl timeout: $(<$t/pl)"; fail=1; }
command mkdir $t/stale.lock; touch -t 202001010000 $t/stale.lock; _prompt_spawn $t/stale true; sleep 0.2
[[ ! -d $t/stale.lock ]] && print "ok   a lock older than 2 min is forgotten" || { print "FAIL stale lock kept"; fail=1; }

render; check " · ✻ 1 agent · 1 busy"$'\n'"$ " "one info line, then a bare bold \$ (literal)"
[[ $raw == *$'\e[38;5;33mmain'* ]] && print "ok   theme: color role from PROMPT_COLOR_*" || { print "FAIL theme color"; fail=1; }
f=$PROMPT_FORMAT
PROMPT_FORMAT='{agents} · {nope} · {dir}'; render; [[ $out == "✻ 1 agent · 1 busy · $t/repo"$'\n'* ]] && print "ok   format: block order, unknown name ignored" || { print "FAIL order: $out"; fail=1; }
PROMPT_FORMAT='[ {docker} | {dir} | {docker} ] %'; render; [[ $out == "[ $t/repo ] %"$'\n'* ]] && print "ok   format: prefix/suffix kept, separators of empty blocks dropped, % literal" || { print "FAIL format text: $out"; fail=1; }
PROMPT_FORMAT='no block'; render; [[ $out == "no block"$'\n'* ]] && print "ok   format: literal only" || { print "FAIL literal: $out"; fail=1; }
PROMPT_FORMAT='{mr} · {dir}'; PROMPT_SHOW_MR=true; render; PROMPT_SHOW_MR=false; [[ $out == "$t/repo"$'\n'* ]] && print "ok   format: {mr} without {git} shows nothing" || { print "FAIL mr alone: $out"; fail=1; }
PROMPT_FORMAT='{hello}'; render; [[ $out == "☺ hi %$USER"$'\n'* && $raw == *$'\e[38;5;42m☺'* ]] && print "ok   local block from prompt.d/: own color + icon, text escaped" || { print "FAIL local block: $out"; fail=1; }
# Per project: shkit writes the files, a project file overrides the theme below its dir.
shkit set format {dir}; command mkdir -p $t/repo/sub/deep $t/repo2; cfg=$XDG_CONFIG_HOME/shkit
shkit project $t/repo/sub >/dev/null; cd sub; shkit set -p format '{dir} P'; shkit set -p color_mute 35
render; [[ $out == "$t/repo/sub P"$'\n'* && $_c_mute == *'[35m'* ]] && print "ok   project file: overrides the theme below its directory" || { print "FAIL project: $out"; fail=1; }
shkit project $t/repo/sub/deep >/dev/null; cd deep; shkit set -p format '{dir} D'
render; [[ $out == "$t/repo/sub/deep D"$'\n'* ]] && print "ok   project file: deepest directory wins" || { print "FAIL project deepest: $out"; fail=1; }
cd $t/repo2; render; [[ $out == "$t/repo2"$'\n'* && $_c_mute != *'[35m'* ]] && print "ok   project file: leaving it (or a same-prefix sibling) puts the theme back" || { print "FAIL project leave: $out $_c_mute"; fail=1; }
shkit set format '{dir} G'; render; [[ $out == "$t/repo2 G"$'\n'* && $(<$cfg/theme.zsh) == *"PROMPT_FORMAT='{dir} G'"* ]] && print "ok   shkit set: theme.zsh written and applied" || { print "FAIL shkit set: $out"; fail=1; }
cd $t/repo/sub; render; [[ $out == "$t/repo/sub P"$'\n'* ]] || { print "FAIL project over new theme: $out"; fail=1; }
ln -s $t/repo $t/link; cd $t/link/sub; render; [[ $out == "$t/link/sub P"$'\n'* ]] && print "ok   project file: found through a symlink too" || { print "FAIL project via symlink: $out"; fail=1; }; cd $t/repo/sub
shkit set -p format '$(touch${IFS}pwned2) {dir}'; render; [[ ! -e pwned2 && $out == '$(touch${IFS}pwned2) '* ]] && print "ok   shkit: a value is written quoted, never run" || { print "FAIL shkit quoting: $out"; fail=1; }
shkit unset -p format; render; [[ $out == "$t/repo/sub G"$'\n'* ]] && print "ok   shkit unset -p: the theme's value again" || { print "FAIL shkit unset: $out"; fail=1; }
shkit unset format >/dev/null; [[ $(<$cfg/theme.zsh) != *PROMPT_FORMAT* ]] || { print "FAIL unset theme"; fail=1; }
cd $t/repo; command rm -r $cfg/projects; _prompt_projects_load
PROMPT_FORMAT=$f
render; [[ $out == "$t/repo · "* ]] && print "ok   theme: empty icon leaves no gap" || { print "FAIL empty icon: $out"; fail=1; }
render 3; [[ $raw == *$'\e[1m\e[31m$'* ]] && print "ok   red \$ after a failed command" || { print "FAIL red \$"; fail=1; }

PROMPT_QUOTA_FILE=$t/quota; print "23.6 $(( EPOCHSECONDS + 60 )) 85 1" >| $t/quota; _prompt_render; out=${${(%)_prompt_right}//$'\e['[0-9;]#m/}
[[ $out == '5h 23%  7d 0%' && $_prompt_right == *$'\e[38;5;141m%}5h%{\e[0m%} %{\e[38;5;150m%}23'* && $_prompt_right == *$'\e[38;5;108m%}0'* ]] && print "ok   quota: right side, rounded, gradient, passed reset = 0%" || { print "FAIL quota: '$out'"; fail=1; }
PROMPT_FORMAT='{dir}' PROMPT_RIGHT_FORMAT='{agents} · {quota}'; _prompt_render; out=${${(%)_prompt_right}//$'\e['[0-9;]#m/}
[[ $out == '✻ 1 agent · 1 busy · 5h 23%  7d 0%' && ${PROMPT#*$'\n'} != *agent* ]] && print "ok   right side: Claude agents + quota, not on the input line" || { print "FAIL right side: '$out'"; fail=1; }
integer wide=$(( ${#t} + 60 ))   # $t is long on macOS (/private/var/folders/…)
COLUMNS=$wide _prompt_render; l=${${(%)PROMPT%%$'\n'*}//$'\e['[0-9;]#m/}
COLUMNS=$(( ${#t} + 20 )) _prompt_render; n=${${(%)PROMPT%%$'\n'*}//$'\e['[0-9;]#m/}
[[ ${(m)#l} == $(( wide - 1 )) && $l == $t/repo' '##$out && $n == $t/repo ]] && print "ok   right side: ends the info line at the terminal's width, dropped when it can't fit" || { print "FAIL right align: '$l' / '$n'"; fail=1; }
PROMPT_FORMAT=$f PROMPT_RIGHT_FORMAT='{quota}'
print -r -- "- 0 54 $(( EPOCHSECONDS + 60 ))" >| $t/quota; _prompt_render; out=${${(%)_prompt_right}//$'\e['[0-9;]#m/}
[[ $out == '5h 0%  7d 54%' ]] && print "ok   quota: 5h not reported = 0%" || { print "FAIL quota 5h missing: '$out'"; fail=1; }
e1=$(( EPOCHSECONDS + 3600 )) e2=$(( EPOCHSECONDS + 3 * 86400 )); strftime -s h1 %H:%M $e1; strftime -s h2 '%a %H:%M' $e2
print -r -- "87 $e1 79 $e2" >| $t/quota; _prompt_render; out=${${(%)_prompt_right}//$'\e['[0-9;]#m/}
[[ $out == "5h 87% ($h1)  7d 79%" ]] && print "ok   quota: reset time from 80%" || { print "FAIL quota reset: '$out'"; fail=1; }
print -r -- "30 $e1 95 $e2" >| $t/quota; _prompt_render; out=${${(%)_prompt_right}//$'\e['[0-9;]#m/}
[[ $out == "5h 30%  7d 95% ($h2)" ]] && print "ok   quota: reset more than 24 h away shows the day" || { print "FAIL quota reset day: '$out'"; fail=1; }
rm -f $t/quota; _prompt_render; [[ -z $_prompt_right ]] && print "ok   quota: no file, nothing shown" || { print "FAIL quota no file"; fail=1; }

# Async: a pending refresh shows ↻ and is watched; the watcher answers once its lock is gone.
_prompt_key docker; lock=$REPLY.lock; mkdir $lock
PROMPT_FORMAT+=' · {docker}'; _prompt_render; PROMPT_FORMAT=$f; out=${${(%)PROMPT}//$'\e['[0-9;]#m/}
[[ $out == *'%↻'* && ${_prompt_pending[1]}.lock == $lock ]] && print "ok   pending refresh: ↻ shown, lock watched" || { print "FAIL pending: $_prompt_pending"; fail=1; }
( sleep 0.3; rmdir $lock ) &
integer ms; s=$EPOCHREALTIME; ans=$(_prompt_watch $_prompt_pending); d=$(( EPOCHREALTIME - s )); ms=$(( d * 1000 ))
[[ $ans == done ]] && (( d < 1.5 )) && print "ok   watcher wakes zle right after the job ($ms ms)" || { print "FAIL watcher: '$ans' after $d s"; fail=1; }
# Plugins: a local repository stands for the remote (no network).
pr=$t/plug; git init -q -b main $pr; git -C $pr config user.email t@t; git -C $pr config user.name t; command mkdir $pr/blocks $pr/themes; cd $t/repo2
print -r -- ': ${PROMPT_COLOR_PL:=38;5;99}; function _prompt_seg_pl { segs+="${_c_pl}plug1${_c_reset}"; }' >|$pr/blocks/pl.zsh
print -r -- 'PROMPT_COLOR_OK=91 PROMPT_COLOR_RUN=95' >|$pr/themes/dark.zsh; print -r -- 'PROMPT_COLOR_RUN=94' >|$pr/themes/light.zsh
print -r -- '{"name": "plug", "version": "1.0.0", "description": "test", "requires": ["no-such-cmd"],
  "blocks": [{"name": "pl", "description": "b"}], "themes": [{"name": "dark", "description": "d"}, {"name": "light", "description": "l"}]}' >|$pr/plugin.json
git -C $pr add -A; git -C $pr commit -qm v1
shkit plugin add $pr </dev/null >/dev/null 2>&1
[[ ! -e $cfg/plugins/plug && -z $(print $cfg/plugins.new/*(N)) ]] && print "ok   plugin add: no yes, nothing kept (staged outside plugins/)" || { print "FAIL plugin add without yes"; fail=1; }
shkit plugin add -y $pr >|$t/pl.out; shkit set format '{pl}'; render
[[ $out == plug1$'\n'* && $raw == *$'\e[38;5;99mplug1'* && $(<$t/pl.out) == *'plug 1.0.0: test'*'sourced: blocks/pl.zsh'*'needs no-such-cmd'* ]] && print "ok   plugin add: manifest shown, its block and the block's color, missing command noted" || { print "FAIL plugin add: $out $(<$t/pl.out)"; fail=1; }
shkit set theme plug/dark; [[ $_c_ok == *'[91m'* && $_c_run == *'[95m'* ]] && print "ok   plugin theme: applied at once" || { print "FAIL plugin theme: $_c_ok"; fail=1; }
shkit set color_ok 92; [[ $_c_ok == *'[92m'* && $_c_run == *'[95m'* ]] && print "ok   theme.zsh over the plugin theme" || { print "FAIL theme.zsh over plugin: $_c_ok"; fail=1; }
shkit project $t/repo2 >/dev/null; shkit set -p theme plug/light; shkit set -p color_ok 93
[[ $_c_ok == *'[93m'* && $_c_run == *'[94m'* ]] && print "ok   project: its own theme and values, over both" || { print "FAIL project theme: $_c_ok $_c_run"; fail=1; }
cd $t/repo; render; [[ $_c_ok == *'[92m'* && $_c_run == *'[95m'* ]] && print "ok   leaving the project: the global theme again" || { print "FAIL leave project theme: $_c_ok $_c_run"; fail=1; }
command rm -r $cfg/projects; _prompt_projects_load
sed -i.bak 's/plug1/plug2/' $pr/blocks/pl.zsh; git -C $pr commit -qam v2
shkit plugin update -y >|$t/pl.out; render
[[ $out == plug2$'\n'* && $(<$t/pl.out) == *v2* ]] && print "ok   plugin update: shows the commits, fast-forwards" || { print "FAIL plugin update: $out"; fail=1; }
sed -i.bak 's/"plug"/"renamed"/' $pr/plugin.json; git -C $pr commit -qam v3; shkit plugin update -y plug >/dev/null 2>|$t/pl.err
[[ $(git -C $cfg/plugins/plug log -1 --format=%s) == v2 && $(<$t/pl.err) == *"renamed to 'renamed'"* ]] && print "ok   plugin update: the new plugin.json is checked first (a rename is refused)" || { print "FAIL update check: $(<$t/pl.err)"; fail=1; }
git -C $pr reset -q --hard HEAD~1; git -C $pr commit -q --amend -m v2b; shkit plugin update -y plug >/dev/null 2>|$t/pl.err
[[ $(git -C $cfg/plugins/plug log -1 --format=%s) == v2 && $(<$t/pl.err) == *rewritten* ]] && print "ok   plugin update: a rewritten history is refused" || { print "FAIL force push: $(<$t/pl.err)"; fail=1; }
print -r -- "touch $t/pwned4" >|$cfg/evil.zsh; shkit set theme 'plug/../../../evil' 2>|$t/pl.err
shkit plugin add -y "--upload-pack=touch $t/pwned5" >/dev/null 2>&1
[[ ! -e $t/pwned4 && ! -e $t/pwned5 && $(<$t/pl.err) == *"not found"* ]] && print "ok   plugin: ../ theme, URL as an option: refused" || { print "FAIL plugin names"; fail=1; }
bad=$t/bad; command cp -R $pr $bad; command rm -rf $bad/.git; git init -q -b main $bad; git -C $bad config user.email t@t; git -C $bad config user.name t
print -r -- 'PROMPT_COLOR_OK=1' >|$bad/themes/extra.zsh; print -r -- 'function nope { }' >|$bad/blocks/pl.zsh
sed -i.bak 's/"1.0.0"/"1.0"/; s/"test"/"test", "extra": 1/' $bad/plugin.json; command rm $bad/plugin.json.bak $bad/blocks/pl.zsh.bak(N)
git -C $bad add -A; git -C $bad commit -qm bad; shkit plugin add -y $bad >/dev/null 2>|$t/pl.err
[[ $(<$t/pl.err) == *'plugin.json.extra: unknown key'*'plugin.json.version'* ]] && print "ok   plugin.json: checked against schema.json" || { print "FAIL schema: $(<$t/pl.err)"; fail=1; }
git -C $bad checkout -q $pr/plugin.json 2>/dev/null; command cp $pr/plugin.json $bad/; git -C $bad commit -qam fix; shkit plugin add -y $bad >/dev/null 2>|$t/pl.err
[[ $(<$t/pl.err) == *'themes/extra.zsh: not declared'*'blocks/pl.zsh: no function _prompt_seg_pl'* && -z $(print $cfg/plugins.new/*(N)) ]] && print "ok   plugin: undeclared file, block without its function: refused, nothing kept" || { print "FAIL layout: $(<$t/pl.err)"; fail=1; }
ex=$t/example; command cp -R $here/plugin/example $ex; git init -q -b main $ex; git -C $ex config user.email t@t; git -C $ex config user.name t; git -C $ex add -A; git -C $ex commit -qm ex
e=$(_shkit_check $ex HEAD 2>&1) && [[ $e == 'example 1.0.0:'* ]] && print "ok   zsh/plugin/example follows the schema" || { print "FAIL example: $e"; fail=1; }
git -C $cfg/plugins/plug remote set-url origin https://me:s3cr3t@git.example/p.git
pl=$(shkit plugin list; shkit plugin add -y 'https://me:s3cr3t@127.0.0.1:1/x.git' 2>&1)
[[ $pl == *'https://git.example/p.git'*'blocks: pl · themes: dark light'* && $pl != *s3cr3t* ]] && print "ok   plugin list / a failed clone: blocks, themes, no token from the URL" || { print "FAIL plugin list: $pl"; fail=1; }
shkit unset theme; shkit plugin remove plug >/dev/null
[[ ! -e $cfg/plugins/plug && -z ${_c_pl-} ]] && print "ok   plugin remove: its files and colors gone" || { print "FAIL plugin remove"; fail=1; }
cd $t; shkit plugin new scaffold >/dev/null; cd scaffold; shkit plugin check >/dev/null 2>&1; e=$?
shkit plugin new-block scaf 'a test' >/dev/null; shkit plugin new-theme night >/dev/null
git config user.email t@t; git config user.name t; git add -A; git commit -qm init
shkit plugin check >|$t/pl.out && shkit plugin add -y $t/scaffold >/dev/null && cd $t/repo2 && shkit set format {scaf} && render
[[ $e != 0 && $(<$t/pl.out) == *valid && $out == scaf$'\n'* && -r $cfg/plugins/scaffold/themes/night.zsh ]] && print "ok   plugin new / new-block / new-theme: a valid plugin, installable as is" || { print "FAIL scaffold: $out $(<$t/pl.out)"; fail=1; }
shkit plugin remove scaffold >/dev/null
ti=$(cd $HOME && PROMPT_FORMAT='{dir}' _prompt_precmd 2>/dev/null)
[[ $ti == *$'\e]0;'"$HOME"$'\a'* ]] && print "ok   tab title: the full path, even in \$HOME" || { print "FAIL title: ${(q)ti}"; fail=1; }
shkit unset format; shkit unset color_ok
up=$t/upstream; git init -q -b main $up; git -C $up config user.email t@t; git -C $up config user.name t
git -C $up commit -q --allow-empty -m one; git clone -q $up $t/sk; _shkit_root=$t/sk
u=$(shkit update -y 2>&1)   # no release branch yet
git -C $up tag v1.0.0; git -C $up commit -q --allow-empty -m two; git -C $up tag v1.1.0; git -C $up branch release   # v1.1.0: CI passed
git -C $up commit -q --allow-empty -m three; git -C $up tag v1.2.0   # v1.2.0: CI failed, release.yml didn't move the branch
[[ $u == *'no release yet'* ]] && u=$(shkit update -y 2>&1) && [[ $u == *'-> v1.1.0'*two* && $(git -C $t/sk describe --tags) == v1.1.0 ]] &&
  u=$(shkit update -y 2>&1) && [[ $u == *'up to date (latest release: v1.1.0)'* ]] &&
  print "ok   shkit update: to the release branch (not a tag CI failed on), then up to date" || { print "FAIL shkit update: $u"; fail=1; }
git -C $t/sk config user.email t@t; git -C $t/sk config user.name t; git -C $t/sk commit -q --allow-empty -m mine; git -C $up branch -f release v1.2.0
u=$(shkit update -y 2>&1); [[ $? != 0 && $u == *"commits v1.2.0 doesn't"* && $(git -C $t/sk log -1 --format=%s) == mine ]] &&
  print "ok   shkit update: a clone with its own commits is left alone" || { print "FAIL shkit update diverged: $u"; fail=1; }
git -C $up branch -f release v1.0.0; u=$(shkit update -y 2>&1); e=$?; git -C $up branch -f release v1.2.0
[[ $e != 0 && $(git -C $t/sk rev-parse origin/release) == $(git -C $up rev-parse v1.2.0) ]] &&
  print "ok   shkit update: a rewritten release branch is refused" || { print "FAIL shkit update rewritten: $u"; fail=1; }
git clone -q $up $t/sk2; git -C $t/sk2 reset -q --hard v1.0.0; _shkit_root=$t/sk2; _prompt_key shkit-update; au=$REPLY
print x >| $t/sk2/dirty; git -C $t/sk2 add dirty; _shkit_job_update $au; d=$(git -C $t/sk2 describe --tags)
git -C $t/sk2 rm -qf dirty; git -C $t/sk2 switch -qc topic; _shkit_job_update $au; d+=" $(git -C $t/sk2 describe --tags)"
git -C $t/sk2 switch -q main; _shkit_job_update $au
u=$(SHKIT_AUTO_UPDATE=true _shkit_autoupdate 2>&1; print "|"; SHKIT_AUTO_UPDATE=true _shkit_autoupdate 2>&1)
[[ $d == 'v1.0.0 v1.0.0' && $(git -C $t/sk2 describe --tags) == v1.2.0 && $u == 'shellkit updated: v1.0.0 -> v1.2.0'*'|' && ! -e $au.lock ]] &&
  print "ok   auto-update: not over local changes nor on another branch; told once; no job within the TTL" || { print "FAIL auto-update: $d $u"; fail=1; }
exit $fail
