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
SHKIT_FORMAT='{dir} · {git} · {mr} · {agents}' SHKIT_RIGHT_FORMAT='{quota}' SHKIT_COLOR_ACCENT='38;5;33' SHKIT_ICON_DIR= SHKIT_ICON_REFRESH='%↻'
SHKIT_SHOW_MR=false SHKIT_AUTO_FETCH=false SHKIT_TITLE_SPINNER=false SHKIT_AUTO_UPDATE=false   # no job on the real clone
command mkdir -p $XDG_CONFIG_HOME/shkit/prompt.d; cat >$XDG_CONFIG_HOME/shkit/prompt.d/hello.zsh <<'EOS'   # a local block: its own color, icon, and an override
: ${SHKIT_COLOR_HELLO:='38;5;42'} ${SHKIT_ICON_HELLO=☺}
function _prompt_seg_hello { _prompt_esc "hi %$USER"; segs+="${_c_hello}${_i_hello} ${REPLY}${_c_reset}"; }
_builtin_docker=$functions[_prompt_seg_docker]; function _prompt_seg_docker { segs+=mine; }
EOS
fail=0
here=${0:A:h}; source $here/prompt.zsh
unalias mkdir mv rm rmdir   # aliases only matter while the prompt is parsed
SHKIT_FORMAT='{docker}' _prompt_render; [[ ${(%)PROMPT} == mine* ]] && print "ok   local block overrides a built-in" || { print "FAIL override"; fail=1; }
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
SHKIT_SHOW_MR=true; render; SHKIT_SHOW_MR=false
check "!2741  draft  ✗" "MR from cache: number, draft, failed CI"
[[ $raw == *$'\e]8;;https://gitlab.example/mr/2741'* ]] && print "ok   MR is an OSC 8 link" || { print "FAIL MR link"; fail=1; }

mkdir $t/bin; cat >$t/bin/docker <<'EOS'   # stub: `timeout` runs a binary, not a function
#!/bin/sh
case "$*" in *--filter*)   # {stack}: one compose project
  printf '%s\t%s\t%s\t%s\n' '' running 'Up 2 hours' nginx '' running 'Up 2 hours (unhealthy)' mysql8 \
    True exited 'Exited (1) 1 hour ago' lmm-run-1 '' exited 'Exited (0) 1 hour ago' minio-init '' exited 'Exited (1) 3 minutes ago' app
  exit ;;
esac
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
f0=$SHKIT_FORMAT; _prompt_key stacklmm; _prompt_job_stack lmm $REPLY; SHKIT_STACK=lmm; SHKIT_FORMAT='{stack}'; render; SHKIT_STACK=
check "lmm 2 ✗ mysql8,app" "stack: services down or unhealthy counted; one-off, exit 0 ignored"
# {ticket}, {review}: from the branch name, and from {mr}'s cache (glab / gh stubs: jq does the GitLab part)
cat >$t/bin/glab <<'EOS'
#!/bin/sh
case "$*" in
*approvals*) echo '{"approved_by":[{},{}]}' ;;
*discussions*) echo '[{"notes":[{"resolvable":true,"resolved":false}]},{"notes":[{"resolvable":true,"resolved":true}]},{"notes":[{"resolvable":false}]}]' ;;
esac
EOS
cat >$t/bin/gh <<'EOS'   # the job's own --jq filter, over a sample GraphQL answer
#!/bin/sh
while [ $# -gt 0 ]; do [ "$1" = --jq ] && f=$2; shift; done
echo '{"data":{"repository":{"pullRequest":{"latestReviews":{"nodes":[{"state":"APPROVED"},{"state":"COMMENTED"}]},
  "reviewThreads":{"nodes":[{"isResolved":false},{"isResolved":true},{"isResolved":false}]}}}}}' | jq -r "$f"
EOS
chmod +x $t/bin/glab $t/bin/gh; rehash
_prompt_job_review $PWD 42 https://gitlab.example/mr/42 $t/rv; _prompt_job_review $PWD 42 https://github.com/o/r/pull/42 $t/rv2
[[ $(<$t/rv) == *$'\n2\t1' && $(<$t/rv2) == *$'\n1\t2' ]] && print "ok   review job: GitLab approvals + unresolved threads (glab, jq), GitHub (gh)" || { print "FAIL review job: $(<$t/rv) / $(<$t/rv2)"; fail=1; }
git switch -qc feature/SHOP-42_x
_prompt_key "mr$PWD/.git@feature/SHOP-42_x"; print -r -- "$EPOCHSECONDS"$'\n42\thttps://gitlab.example/mr/42\t0\topened\tsuccess' >$REPLY
_prompt_key "review$PWD/.git@42"; command cp $t/rv $REPLY
SHKIT_FORMAT='{git} · {ticket} · {mr}  {review}' SHKIT_TICKET_URL='https://tracker.example/t/{id}' SHKIT_SHOW_MR=true; render
check " · "$'\uf0ae'" SHOP-42 · "$'\uf296'" !42  ✓  "$'\uf164'" 2  "$'\uf086'" 1" "ticket from the branch, review of its MR"
[[ $raw == *$'\e]8;;https://tracker.example/t/SHOP-42\e\\'* ]] && print "ok   ticket: a link to SHKIT_TICKET_URL" || { print "FAIL ticket link"; fail=1; }
SHKIT_TICKET_URL= SHKIT_ICON_TICKET=; _prompt_theme; render; [[ $out != *' · SHOP-42'* ]] && print "ok   ticket: no URL, no block" || { print "FAIL ticket without URL: $out"; fail=1; }
SHKIT_SHOW_MR=false SHKIT_ICON_TICKET=$'\uf0ae'; _prompt_theme; git switch -q main
# {duration}, {status}, {host}
SHKIT_FORMAT='{host} · {duration} · {status}'
_prompt_elapsed=2; render; e=$out; _prompt_elapsed=65; render 2; e+="|$out"; _prompt_elapsed=7300; render 130; e+="|$out"
[[ $e == $'\n'*"|"$'\uf017'" 1m05s · ✗ 2"$'\n'*"|"$'\uf017'" 2h01m · ✗ INT"$'\n'* ]] && print "ok   duration from 3 s (1m05s, 2h01m), status: the code or its signal" || { print "FAIL duration/status: $e"; fail=1; }
_prompt_elapsed=0; SSH_CONNECTION='10.0.0.1 1 10.0.0.2 22' render; [[ $out == "$USERNAME@${HOST%%.*}"$'\n'* ]] && print "ok   host: shown over SSH (root: not testable, EUID is readonly)" || { print "FAIL host: $out"; fail=1; }
# A long command: notified by name only (not its line), not when a part of it is ignored;
# notify-send (with a display), else osascript (macOS), else the bell
print -r -- '#!/bin/sh'$'\n''printf "%s|" "$@" >'$t/notified >$t/bin/notify-send; command cp $t/bin/notify-send $t/bin/osascript
for c in make vim; do print '#!/bin/sh' >$t/bin/$c; done; chmod +x $t/bin/{notify-send,osascript,make,vim}; rehash
nt() { command rm -f $t/notified; ( op=($path); path=($t/bin); DISPLAY=${DISPLAY-:0}; _prompt_start=$(( EPOCHREALTIME - $1 )); _prompt_cmd=$2; rc() { return $1; }; rc ${3:-0}; _prompt_precmd >/dev/null 2>&1; path=($op) ); integer i; for (( i = 0; i < 20; i++ )); do [[ -s $t/notified ]] && break; sleep 0.05; done; }
nt 45 'FOO=s3cr3t make build'; e=$(<$t/notified)
for l in 'vim notes' 'sudo -E vim /etc/x' 'make && vim x' '(cd x; vim y)'; do nt 45 $l; [[ -e $t/notified ]] && e+=" notified: $l"; done
nt 5 make; [[ -e $t/notified ]] && e+=" short notified"
nt 45 make 130; nt 45 make $(( ${signals[(i)TSTP]} + 127 )); [[ -e $t/notified ]] && e+=" ^C / ^Z notified"
nt 45 'sudo -u root nice make'; [[ $(<$t/notified) == *'|✓ make done|'* ]] || e+=" sudo -u: $(<$t/notified)"
nt 45 '{ cd x && make; }'; [[ $(<$t/notified) == *'|✓ make done|'* ]] || e+=" cd && make: $(<$t/notified)"
SHKIT_NOTIFY_IGNORE='vim make'; nt 45 make; [[ -e $t/notified ]] && e+=" one-string ignore list"; SHKIT_NOTIFY_IGNORE=(vim)
command mkdir -p $t/'a<b>&c'; cd $t/'a<b>&c'; nt 45 make; [[ $(<$t/notified) == *"|<b>45s</b>  ·  $t/a&lt;b&gt;&amp;c|" ]] || e+=" markup not escaped"; cd $t/repo
SHKIT_NOTIFY=false; nt 45 make; [[ -e $t/notified ]] && e+=" off notified"; SHKIT_NOTIFY=true
SHKIT_NOTIFY_TIMEOUT=5000; nt 45 make; [[ $(<$t/notified) == *'|-t|5000|--|'* ]] || e+=" no timeout"; SHKIT_NOTIFY_TIMEOUT=
DISPLAY= WAYLAND_DISPLAY= nt 45 make; [[ $(<$t/notified) == *'|on run argv|'* ]] || e+=" no display: not osascript"
mv $t/bin/notify-send $t/ns; rehash; nt 45 'sudo make' 3; e+=" / $(<$t/notified)"; mv $t/ns $t/bin/notify-send; rehash
[[ $e == "-a|shellkit|-i|emblem-default|--|✓ make done|<b>45s</b>  ·  $PWD| / -e|on run argv|"*"end run|shellkit|✗ make failed · exit 3|45s  ·  $PWD|" ]] && print "ok   notify: name only (past sudo -u, cd &&), ignored parts, ^C / ^Z, off switch, timeout, markup; notify-send, else osascript (text as arguments)" || { print "FAIL notify: $e"; fail=1; }
SHKIT_FORMAT=$f0
command mkdir $t/stale.lock; touch -t 202001010000 $t/stale.lock; _prompt_spawn $t/stale true; sleep 0.2
[[ ! -d $t/stale.lock ]] && print "ok   a lock older than 2 min is forgotten" || { print "FAIL stale lock kept"; fail=1; }
_prompt_spawn $t/race sleep 1; [[ -d $t/race.lock ]] && print "ok   a job's lock exists as soon as it is spawned (the prompt waits for it)" || { print "FAIL lock taken late: no ↻, no redraw"; fail=1; }

render; check " · ✻ 1 agent · 1 busy"$'\n'"$ " "one info line, then a bare bold \$ (literal)"
[[ $raw == *$'\e[38;5;33mmain'* ]] && print "ok   theme: color role from SHKIT_COLOR_*" || { print "FAIL theme color"; fail=1; }
f=$SHKIT_FORMAT
SHKIT_FORMAT='{agents} · {nope} · {dir}'; render; [[ $out == "✻ 1 agent · 1 busy · $t/repo"$'\n'* ]] && print "ok   format: block order, unknown name ignored" || { print "FAIL order: $out"; fail=1; }
SHKIT_FORMAT='[ {docker} | {dir} | {docker} ] %'; render; [[ $out == "[ $t/repo ] %"$'\n'* ]] && print "ok   format: prefix/suffix kept, separators of empty blocks dropped, % literal" || { print "FAIL format text: $out"; fail=1; }
SHKIT_FORMAT='no block'; render; [[ $out == "no block"$'\n'* ]] && print "ok   format: literal only" || { print "FAIL literal: $out"; fail=1; }
SHKIT_FORMAT='{mr} · {dir}'; SHKIT_SHOW_MR=true; render; SHKIT_SHOW_MR=false; [[ $out == "$t/repo"$'\n'* ]] && print "ok   format: {mr} without {git} shows nothing" || { print "FAIL mr alone: $out"; fail=1; }
SHKIT_FORMAT='{hello}'; render; [[ $out == "☺ hi %$USER"$'\n'* && $raw == *$'\e[38;5;42m☺'* ]] && print "ok   local block from prompt.d/: own color + icon, text escaped" || { print "FAIL local block: $out"; fail=1; }
# {dir.short}: from the repository's root, ~ for $HOME, else in full
command mkdir -p $t/repo/s/d $HOME/p; SHKIT_FORMAT='{dir.short}'; e=
for d in $t/repo/s/d $t/repo $HOME/p $HOME $t; do cd $d; render; e+="${out%%$'\n'*}|"; done; cd $t/repo
[[ $e == "repo/s/d|repo|~/p|~|$t|" ]] && print "ok   dir.short: repo/s/d, ~/p, else in full" || { print "FAIL dir.short: $e"; fail=1; }
# {git.untracked}: counted by a job (a directory once), redrawn without ↻
print x >u1; command mkdir -p s/n && print y >s/n/a && print z >s/n/b
SHKIT_FORMAT='{git} · {git.untracked}'; _prompt_key untracked$t/repo; uf=$REPLY
_prompt_render 1; e="$_prompt_pending"; for (( i = 0; i < 40; i++ )); do [[ -d $uf.lock ]] || break; sleep 0.05; done
[[ $e == "0 $uf" && $PROMPT != *↻* ]] && render && [[ ${out%%$'\n'*} == *main*" · ?2" ]] &&
  print "ok   git.untracked: counted in the background (s/ once), watched without ↻" || { print "FAIL git.untracked: $e / $out"; fail=1; }
command rm -r u1 s; _prompt_job_untracked $t/repo $uf; render; [[ $out != *'?'* ]] && print "ok   git.untracked: none, no block" || { print "FAIL git.untracked none: $out"; fail=1; }
# SHKIT_TRANSIENT: a line run, the prompt shrinks to its $ line
function zle { : }; SHKIT_TRANSIENT=true; _prompt_render; e=${PROMPT##*$'\n'}; _prompt_transient
[[ $PROMPT == "$e" && $PROMPT == *'$'* ]] && { SHKIT_TRANSIENT=false; _prompt_render; _prompt_transient; [[ $PROMPT == *$'\n'* ]] } &&
  print "ok   transient: \$ line only, off by default" || { print "FAIL transient: $PROMPT"; fail=1; }
unfunction zle; SHKIT_TRANSIENT=false
# Per project: shkit writes the files, a project file overrides the theme below its dir.
shkit set format {dir}; command mkdir -p $t/repo/sub/deep $t/repo2; cfg=$XDG_CONFIG_HOME/shkit
shkit project $t/repo/sub >/dev/null; cd sub; shkit set -p format '{dir} P'; shkit set -p color_mute 35
render; [[ $out == "$t/repo/sub P"$'\n'* && $_c_mute == *'[35m'* ]] && print "ok   project file: overrides the theme below its directory" || { print "FAIL project: $out"; fail=1; }
shkit project $t/repo/sub/deep >/dev/null; cd deep; shkit set -p format '{dir} D'
render; [[ $out == "$t/repo/sub/deep D"$'\n'* ]] && print "ok   project file: deepest directory wins" || { print "FAIL project deepest: $out"; fail=1; }
cd $t/repo2; render; [[ $out == "$t/repo2"$'\n'* && $_c_mute != *'[35m'* ]] && print "ok   project file: leaving it (or a same-prefix sibling) puts the theme back" || { print "FAIL project leave: $out $_c_mute"; fail=1; }
shkit set format '{dir} G'; render; [[ $out == "$t/repo2 G"$'\n'* && $(<$cfg/theme.zsh) == *"SHKIT_FORMAT='{dir} G'"* ]] && print "ok   shkit set: theme.zsh written and applied" || { print "FAIL shkit set: $out"; fail=1; }
cd $t/repo/sub; render; [[ $out == "$t/repo/sub P"$'\n'* ]] || { print "FAIL project over new theme: $out"; fail=1; }
ln -s $t/repo $t/link; cd $t/link/sub; render; [[ $out == "$t/link/sub P"$'\n'* ]] && print "ok   project file: found through a symlink too" || { print "FAIL project via symlink: $out"; fail=1; }; cd $t/repo/sub
shkit set -p format '$(touch${IFS}pwned2) {dir}'; render; [[ ! -e pwned2 && $out == '$(touch${IFS}pwned2) '* ]] && print "ok   shkit: a value is written quoted, never run" || { print "FAIL shkit quoting: $out"; fail=1; }
shkit unset -p format; render; [[ $out == "$t/repo/sub G"$'\n'* ]] && print "ok   shkit unset -p: the theme's value again" || { print "FAIL shkit unset: $out"; fail=1; }
shkit unset format >/dev/null; [[ $(<$cfg/theme.zsh) != *SHKIT_FORMAT* ]] || { print "FAIL unset theme"; fail=1; }
cd $t/repo; command rm -r $cfg/projects; _prompt_projects_load
# shellkit 1.0's PROMPT_* names: from the environment, theme.zsh, a project file; shkit renames a file it edits
o=$(PROMPT_FORMAT='{dir}X' zsh -fc 'source $1/prompt.zsh; print -r -- $SHKIT_FORMAT $+PROMPT_FORMAT' _ $here 2>&1)
print -r -- "PROMPT_FORMAT='{dir} OLD'" >| $cfg/theme.zsh; command mkdir $cfg/projects
print -rl -- "PROMPT_PROJECT_DIR='$t/repo2'" "PROMPT_COLOR_MUTE=36" >| $cfg/projects/old.zsh; _prompt_projects_load; _shkit_reset
render; e="$out|$+PROMPT_FORMAT"; cd $t/repo2; render; e+="|$_c_mute"; cd $t/repo; shkit set color_ok 92
[[ $o == '{dir}X 1' && $e == "$t/repo OLD"$'\n'*'|1|'*'[36m'* && $(<$cfg/theme.zsh) == "SHKIT_FORMAT='{dir} OLD'"$'\n'"SHKIT_COLOR_OK=92" ]] &&
  print "ok   PROMPT_* (shellkit 1.0) still read: environment, theme.zsh, project file (and mirrored for 1.0 blocks); shkit set renames them" || { print "FAIL compat: $o | $e | $(<$cfg/theme.zsh)"; fail=1; }
print -rl -- "#PROMPT_ICON_A=x  PROMPT_ICON_B=y" "setopt PROMPT_SUBST" "PROMPT_EOL_MARK=''" >| $cfg/theme.zsh
print -rl -- "export PROMPT_SHOW_MR=false" "export PROMPT_COMMAND='history -a' PROMPT_DIRTRIM=3" >| $cfg/settings.sh
bash $here/../shell/install-local.sh >/dev/null 2>&1
[[ $(<$cfg/theme.zsh) == "#SHKIT_ICON_A=x  SHKIT_ICON_B=y"$'\n'"setopt PROMPT_SUBST"$'\n'"PROMPT_EOL_MARK=''" && -r $cfg/theme.zsh.bak &&
   $(<$cfg/settings.sh) == "export SHKIT_SHOW_MR=false"$'\n'"export PROMPT_COMMAND='history -a' PROMPT_DIRTRIM=3" && $(<$cfg/projects/old.zsh) == SHKIT_PROJECT_DIR=* ]] &&
  print "ok   install-local.sh renames PROMPT_* assignments (commented ones too, a .bak kept), not bash's or zsh's own" || { print "FAIL install-local rename: $(<$cfg/theme.zsh) | $(<$cfg/settings.sh)"; fail=1; }
shkit set color_ok 91; [[ $(<$cfg/theme.zsh) == *"PROMPT_EOL_MARK=''"* && $(shkit doctor 2>&1) != *'1.0 names'* ]] && print "ok   shkit set, doctor: PROMPT_EOL_MARK / PROMPT_COMMAND are not 1.0 names" || { print "FAIL foreign names: $(<$cfg/theme.zsh)"; fail=1; }
command rm -r $cfg/projects $cfg/theme.zsh{,.bak} $cfg/settings.sh{,.bak}; _prompt_projects_load; _shkit_reset
# a 1.0 block reading PROMPT_* as it renders; bash's PROMPT_COMMAND from the environment left alone
print -r -- ': ${PROMPT_OLD_TTL:=900}; function _prompt_seg_old { segs+="ttl=$PROMPT_OLD_TTL mr=$PROMPT_SHOW_MR"; }' >| $cfg/prompt.d/old.zsh
o=$(PROMPT_COMMAND='history -a' zsh -fc 'source $1/prompt.zsh; SHKIT_FORMAT={old}; _prompt_render; print -r -- "${(%)PROMPT%%$'"'"'\n'"'"'*} $SHKIT_OLD_TTL [$PROMPT_COMMAND]"' _ $here 2>&1)
command rm $cfg/prompt.d/old.zsh
[[ $o == 'ttl=900 mr=true 900 [history -a]' ]] && print "ok   a 1.0 block still reads PROMPT_* as it renders; PROMPT_COMMAND untouched" || { print "FAIL 1.0 block: $o"; fail=1; }
SHKIT_FORMAT=$f
render; [[ $out == "$t/repo · "* ]] && print "ok   theme: empty icon leaves no gap" || { print "FAIL empty icon: $out"; fail=1; }
render 3; [[ $raw == *$'\e[1m\e[31m$'* ]] && print "ok   red \$ after a failed command" || { print "FAIL red \$"; fail=1; }

SHKIT_QUOTA_FILE=$t/quota; print "23.6 $(( EPOCHSECONDS + 60 )) 85 1" >| $t/quota; _prompt_render; out=${${(%)_prompt_right}//$'\e['[0-9;]#m/}
[[ $out == '5h 23%  7d 0%' && $_prompt_right == *$'\e[38;5;141m%}5h%{\e[0m%} %{\e[38;5;150m%}23'* && $_prompt_right == *$'\e[38;5;108m%}0'* ]] && print "ok   quota: right side, rounded, gradient, passed reset = 0%" || { print "FAIL quota: '$out'"; fail=1; }
SHKIT_FORMAT='{dir}' SHKIT_RIGHT_FORMAT='{agents} · {quota}'; _prompt_render; out=${${(%)_prompt_right}//$'\e['[0-9;]#m/}
[[ $out == '✻ 1 agent · 1 busy · 5h 23%  7d 0%' && ${PROMPT#*$'\n'} != *agent* ]] && print "ok   right side: Claude agents + quota, not on the input line" || { print "FAIL right side: '$out'"; fail=1; }
integer wide=$(( ${#t} + 60 ))   # $t is long on macOS (/private/var/folders/…)
COLUMNS=$wide _prompt_render; l=${${(%)PROMPT%%$'\n'*}//$'\e['[0-9;]#m/}
COLUMNS=$(( ${#t} + 20 )) _prompt_render; n=${${(%)PROMPT%%$'\n'*}//$'\e['[0-9;]#m/}
[[ ${(m)#l} == $(( wide - 1 )) && $l == $t/repo' '##$out && $n == $t/repo ]] && print "ok   right side: ends the info line at the terminal's width, dropped when it can't fit" || { print "FAIL right align: '$l' / '$n'"; fail=1; }
SHKIT_FORMAT=$f SHKIT_RIGHT_FORMAT='{quota}'
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
SHKIT_FORMAT+=' · {docker}'; _prompt_render; SHKIT_FORMAT=$f; out=${${(%)PROMPT}//$'\e['[0-9;]#m/}
[[ $out == *'%↻'* && ${_prompt_pending[2]}.lock == $lock ]] && print "ok   pending refresh: ↻ shown, lock watched" || { print "FAIL pending: $_prompt_pending"; fail=1; }
( sleep 0.3; rmdir $lock ) &
integer ms; s=$EPOCHREALTIME; ans=$(_prompt_watch $_prompt_pending); d=$(( EPOCHREALTIME - s )); ms=$(( d * 1000 ))
[[ $ans == done ]] && (( d < 1.5 )) && print "ok   watcher wakes zle right after the job ($ms ms)" || { print "FAIL watcher: '$ans' after $d s"; fail=1; }
e=
for n in 0 1; do   # the title at each turn (a write truncates the file): sleep logs it
  mkdir $lock; ( sleep 0.3; rmdir $lock ) &
  ( setopt clobber; TTY=$t/tty SHKIT_TITLE_SPINNER=true; : >$TTY; : >$t/titles; print -r -- "0 t" >$_prompt_cache/state.$$
    function sleep { cat $TTY >>$t/titles; command sleep $1 }; _prompt_watch $n ${lock%.lock} >/dev/null )
  e+="$(<$t/titles)|"
done
[[ $e == '|'*'· sync'* ]] && print "ok   watcher: a quiet lock ({git.untracked}) doesn't spin the title, others do" || { print "FAIL spinner: $e"; fail=1; }
# Plugins: a local repository stands for the remote (no network).
pr=$t/plug; git init -q -b main $pr; git -C $pr config user.email t@t; git -C $pr config user.name t; command mkdir $pr/blocks $pr/themes; cd $t/repo2
print -r -- ': ${SHKIT_COLOR_PL:=38;5;99}; function _prompt_seg_pl { segs+="${_c_pl}plug1${_c_reset}"; }' >|$pr/blocks/pl.zsh
print -r -- 'SHKIT_COLOR_OK=91 SHKIT_COLOR_RUN=95' >|$pr/themes/dark.zsh; print -r -- 'SHKIT_COLOR_RUN=94' >|$pr/themes/light.zsh
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
print -r -- 'SHKIT_COLOR_OK=1' >|$bad/themes/extra.zsh; print -r -- 'function nope { }' >|$bad/blocks/pl.zsh
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
ti=$(cd $HOME && SHKIT_FORMAT='{dir}' _prompt_precmd 2>/dev/null)
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
doc=$(shkit doctor 2>&1); e=$?; print x >| $cfg/secrets.sh; chmod 644 $cfg/secrets.sh; shkit doctor >|$t/doc 2>&1; e2=$?
chmod 400 $cfg/secrets.sh; shkit doctor >/dev/null 2>&1; e2+=$?; command rm -f $cfg/secrets.sh
[[ $e == 0 && $doc == *'ok   zsh '*'ok   git '*'ok   locale '* && $e2 == 10 && $(<$t/doc) == *'FAIL secrets.sh: readable by others'* ]] && print "ok   shkit doctor: warnings pass, secrets.sh readable by others fails (400 is fine)" || { print "FAIL doctor ($e/$e2): $doc"; fail=1; }
command mkdir -p $HOME/.local/share/fonts; : >| $HOME/.local/share/fonts/SymbolsNerdFont-Regular.ttf
doc=$( unhash fc-list 2>/dev/null; shkit doctor 2>&1 ); command rm $HOME/.local/share/fonts/SymbolsNerdFont-Regular.ttf
[[ $doc == *'ok   a Nerd Font is installed'* ]] && print "ok   shkit doctor: no fc-list (macOS), the font directories are looked at" || { print "FAIL doctor font: $doc"; fail=1; }
exit $fail
