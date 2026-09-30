# prompt.zsh — Claude Code–flavoured prompt: every fact on line 1, input on line 2.
#
#    ~/code/shop · SHOP-4966 wt · ⇣3  ⇡1   4 +120 −38 · !1234  ✓ ·  2 mysql8,nginx ↻
#   $                                        ✻ 4 agents · 1 busy · 5h 23%  7d 41%
#
# Theme (layout: PROMPT_FORMAT, colors, icons): ~/.config/shkit/theme.zsh, over a
# plugin's theme (see _prompt_compose). Colors are ROLES (those of ~/.claude/statusline-command.sh,
# plus AGENT = Claude orange), each an SGR code: PROMPT_COLOR_ACCENT='38;5;33'.
#
# Async: the synchronous path (every prompt) stays local, < 50 ms even on a large
# repository (35k files). Networked data (git fetch, MR/PR + CI, docker) is read from a
# cache under $XDG_RUNTIME_DIR; stale entries are refreshed by background
# jobs, and a watcher tells zle when they are done (zle -F), which redraws the
# prompt in place (zle reset-prompt) — no Enter needed. A muted ↻ = refresh in
# flight; the tab title spins meanwhile.
#
# Security: PROMPT_SUBST stays off and every dynamic text goes through
# _prompt_esc, so a branch named '$(…)' or '%F' is printed, never run.

zmodload zsh/datetime zsh/system
zmodload -F zsh/stat b:zstat   # zstat only: a plain load would shadow the stat binary

# No XDG_RUNTIME_DIR on macOS: its $TMPDIR is per-user too.
typeset -g _prompt_cache=${XDG_RUNTIME_DIR:-${${TMPDIR:-/tmp}%/}/zsh-prompt-$UID}/zsh-prompt
command mkdir -p -m 700 $_prompt_cache 2>/dev/null
typeset -g _prompt_fd=   # watcher of the current refresh, if any

function _prompt_esc { REPLY=${1//\%/%%}; }   # dynamic text -> literal in PROMPT

# Defaults: the bottom layer, under plugin theme < settings.sh < theme.zsh < project
# (_prompt_compose). A theme sets the same names in ~/.config/shkit/theme.zsh.
function _prompt_defaults {
  : ${PROMPT_SHOW_MR:=true}        # MR/PR + CI (glab / gh, cached)
  : ${PROMPT_QUOTA_FILE:=${XDG_CACHE_HOME:-$HOME/.cache}/claude-quota}
  : ${PROMPT_QUOTA_RESET_AT:=80}   # from this %, the quota also shows when it resets
  : ${PROMPT_AUTO_FETCH:=true}     # background `git fetch`, for a true ⇣N
  : ${PROMPT_TITLE_SPINNER:=true}  # spinner in the tab title while a refresh runs
  : ${PROMPT_FETCH_TTL:=300}
  : ${PROMPT_MR_TTL:=120}          # 20 s while a pipeline is running
  : ${PROMPT_DOCKER_TTL:=30}
  : ${PROMPT_DIFF_MAX_FILES:=50}   # +/- skipped above this (556 files = 85 ms on a 35k-file repository)

  # Layout: {block} placeholders and literal text (muted). Blocks: dir, git, mr
  # (needs {git} before it), docker (anomalies only), agents (Claude sessions),
  # quota (Claude 5h / 7d). Text between two blocks is a separator: shown only
  # when a block on each side shows (the one before the next shown block wins).
  # Text before the first block / after the last one always shows. An unknown
  # name shows nothing. RIGHT = right-aligned at the end of the info line.
  : ${PROMPT_FORMAT='{dir} · {git} · {mr} · {docker}'}
  : ${PROMPT_RIGHT_FORMAT='{agents} · {quota}'}
  : ${PROMPT_SEPARATOR:=' · '}   # inside a block: git = branch · status · rebase

  : ${PROMPT_COLOR_PRIMARY:='1;32'}     ${PROMPT_COLOR_ACCENT:='36'}
  : ${PROMPT_COLOR_MUTE:='38;5;248'}    ${PROMPT_COLOR_WARN:='38;5;208'}
  : ${PROMPT_COLOR_ADDED:='38;5;114'}   ${PROMPT_COLOR_REMOVED:='38;5;174'}
  : ${PROMPT_COLOR_OK:='32'}          ${PROMPT_COLOR_FAIL:='31'}
  : ${PROMPT_COLOR_RUN:='34'}         ${PROMPT_COLOR_AGENT:='38;5;173'}
  : ${PROMPT_COLOR_QUOTA_5H:='38;5;141'} ${PROMPT_COLOR_QUOTA_7D:='38;5;99'}   # labels, as the statusline (not bold)
  # Quota % gradient (256-color), low -> high, ratio^1.3 — the statusline's QUOTA_PALETTE.
  (( ${+PROMPT_QUOTA_PALETTE} )) || PROMPT_QUOTA_PALETTE=(108 108 150 150 185 185 227 227 221 221 215 215 209 209 167)

  # Icons (Nerd Font for dir/gitlab/github/docker). Set one to '' to drop it.
  # `=` not `:=`: an icon set empty stays empty.
  : ${PROMPT_ICON_DIR=}        ${PROMPT_ICON_BRANCH=}      ${PROMPT_ICON_GITLAB=$'\uf296'}
  : ${PROMPT_ICON_GITHUB=$'\uf09b'}  ${PROMPT_ICON_DOCKER=$'\uf308'}  ${PROMPT_ICON_AGENT=✻}
  : ${PROMPT_ICON_BEHIND=⇣}  ${PROMPT_ICON_AHEAD=⇡}  ${PROMPT_ICON_DIRTY=$'\uf044'}
  : ${PROMPT_ICON_ADDED=+}   ${PROMPT_ICON_REMOVED=−}  ${PROMPT_ICON_CONFLICT=✗}
  : ${PROMPT_ICON_CI_OK=✓}   ${PROMPT_ICON_CI_FAIL=✗}  ${PROMPT_ICON_CI_SKIP=○}  ${PROMPT_ICON_CI_RUN=●}
  : ${PROMPT_ICON_REFRESH=↻}  ${PROMPT_ICON_PROMPT='$'}
  (( ${+PROMPT_SPINNER} )) || PROMPT_SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)   # tab title
}

#------------------------------------------------------------------------------
# Cache: "<epoch>\n<tab-separated data>". Missing or stale -> refresh.

function _prompt_key { local k=${1//\//%}; REPLY=$_prompt_cache/${k// /_}; }

function _prompt_read { # FILE -> _ts, _data
  _ts=0 _data=
  [[ -r $1 ]] && { IFS= read -r _ts; IFS= read -r _data; } <$1
  [[ $_ts == <-> ]] || _ts=0
}

function _prompt_write { # FILE DATA — atomic, so the prompt never reads half a file
  print -r -- $EPOCHSECONDS$'\n'$2 >| $1.$sysparams[pid] && command mv -f $1.$sysparams[pid] $1
}

# _prompt_spawn FILE CMD... — run CMD detached, at most one per FILE (lock dir).
function _prompt_spawn {
  local file=$1; shift
  _prompt_locked $file && return 0
  {
    command mkdir $file.lock 2>/dev/null || exit
    trap "command rmdir ${(q)file}.lock 2>/dev/null" EXIT
    "$@"
  } </dev/null >/dev/null 2>&1 &!
}

# A job killed mid-flight leaves its lock behind: forget locks older than 2 min.
function _prompt_locked {
  [[ -d $1.lock ]] || return 1
  local -a m; zstat -A m +mtime -- $1.lock 2>/dev/null || return 1
  (( EPOCHSECONDS - m[1] < 120 )) && return 0
  command rmdir $1.lock 2>/dev/null; return 1
}

#------------------------------------------------------------------------------
# Background jobs (detached, never on the prompt's critical path).

# `timeout` is GNU coreutils: macOS has none, or `gtimeout` with coreutils from
# Homebrew. Else perl, which macOS ships: its alarm survives the exec.
function _prompt_timeout { # SECS CMD...
  if (( $+commands[timeout] )); then command timeout "$@"
  elif (( $+commands[gtimeout] )); then command gtimeout "$@"
  else perl -e 'alarm shift; exec @ARGV or exit 127' -- "$@"
  fi
}

function _prompt_job_fetch { # TOPLEVEL FILE
  _prompt_write $2 ""   # stamp first: a failing fetch retries after the TTL, not every prompt
  [[ -n $(git -C $1 remote) ]] || return
  GIT_TERMINAL_PROMPT=0 GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' \
    _prompt_timeout 60 git -C $1 fetch --quiet --no-tags --no-write-fetch-head --no-auto-maintenance
}

# Output: "<number>\t<url>\t<draft 0|1>\t<state opened|merged|closed>\t<ci>"
function _prompt_job_mr { # TOPLEVEL BRANCH FILE
  local data=
  cd $1 || return
  # no upstream = never pushed = no MR: skips a network call on local branches
  if git rev-parse --verify --quiet "$2@{u}" >/dev/null; then
    case $(git remote get-url origin 2>/dev/null) in
    *github.com*)
      (( $+commands[gh] )) &&
        data=$(_prompt_timeout 5 gh pr view $2 --json number,url,isDraft,state,statusCheckRollup --jq '
          [ (.statusCheckRollup // [])[]
            | if (.conclusion // "") != "" then .conclusion else (.state // .status) end ] as $s
          | [ .number, .url, (if .isDraft then 1 else 0 end),
              (.state | ascii_downcase | if . == "open" then "opened" else . end),
              (if ($s | length) == 0 then ""
               elif any($s[]; . == "FAILURE" or . == "ERROR" or . == "CANCELLED" or . == "TIMED_OUT") then "failed"
               elif all($s[]; . == "SUCCESS" or . == "NEUTRAL" or . == "SKIPPED") then "success"
               else "running" end) ] | @tsv') ;;
    *)
      (( $+commands[glab] )) &&
        data=$(_prompt_timeout 5 glab mr view $2 -F json 2>/dev/null | jq -r 'select(.iid != null) |
          [ .iid, .web_url, (if .draft then 1 else 0 end), .state,
            (.head_pipeline.status // "") ] | @tsv') ;;
    esac
  fi
  _prompt_write $3 $data
}

# Anomalies only: unhealthy / restarting anywhere, or a non-zero exit inside a
# compose project that is otherwise up (a stack that is half down).
# Output: "<count>\t<first names>"
function _prompt_job_docker { # FILE
  local data
  data=$(_prompt_timeout 3 docker ps -a --format \
    '{{.Label "com.docker.compose.project"}}	{{.Label "com.docker.compose.oneoff"}}	{{.State}}	{{.Status}}	{{.Names}}' |
    awk -F'\t' '
      { p[NR] = $1; o[NR] = $2; st[NR] = $3; s[NR] = $4; n[NR] = $5; if ($3 == "running" && $1 != "") up[$1] = 1 }
      END {
        for (i = 1; i <= NR; i++) {
          bad = s[i] ~ /unhealthy/ || st[i] == "restarting" || st[i] == "dead" ||
                (st[i] == "exited" && s[i] !~ /^Exited \(0\)/ && p[i] != "" && up[p[i]] && o[i] != "True")
          if (bad && ++c <= 2) names = names (names ? "," : "") n[i]
        }
        if (c) printf "%d\t%s", c, names
      }')
  _prompt_write $1 $data
}

#------------------------------------------------------------------------------
# Segments (synchronous, local): _prompt_seg_<name> appends its text to
# `segs`, and to `pending` the cache files whose refresh is in flight (watched
# for redraw). A new segment = a new _prompt_seg_<name> + its {name} in PROMPT_FORMAT.
# With SPAWN set, stale entries get a background refresh.

function _prompt_seg_git {
  local -a rp
  rp=("${(@f)$(GIT_OPTIONAL_LOCKS=0 git rev-parse --path-format=absolute \
    --git-dir --git-common-dir --show-toplevel 2>/dev/null)}")
  (( ${#rp} == 3 )) || return 0
  local gitdir=$rp[1] common=$rp[2] top=$rp[3]

  local line head= oid= ahead=0 behind=0 files=0 conflicts=0 upstream=
  while IFS= read -r line; do
    case $line in
    ('# branch.oid '*) oid=${line#'# branch.oid '} ;;
    ('# branch.head '*) head=${line#'# branch.head '} ;;
    ('# branch.upstream '*) upstream=1 ;;
    ('# branch.ab '*) line=${line#'# branch.ab +'}; ahead=${line%% *}; behind=${line##*-} ;;
    ('u '*) (( files++, conflicts++ )) ;;
    ([12]' '*) (( files++ )) ;;
    esac
  done < <(GIT_OPTIONAL_LOCKS=0 git status --porcelain=v2 --branch -uno 2>/dev/null)
  # -uno = untracked files not counted (114 ms vs 18 ms on a 35k-file repository)

  # In-progress operation (282 rebases in the history: worth a glance).
  local op= n m
  if [[ -d $gitdir/rebase-merge ]]; then
    read -r n <$gitdir/rebase-merge/msgnum; read -r m <$gitdir/rebase-merge/end
    op="rebase $n/$m"; read -r head <$gitdir/rebase-merge/head-name
  elif [[ -d $gitdir/rebase-apply ]]; then
    read -r n <$gitdir/rebase-apply/next; read -r m <$gitdir/rebase-apply/last
    op="rebase $n/$m"; [[ -r $gitdir/rebase-apply/head-name ]] && read -r head <$gitdir/rebase-apply/head-name
  elif [[ -f $gitdir/MERGE_HEAD ]]; then op=merge
  elif [[ -f $gitdir/CHERRY_PICK_HEAD ]]; then op=cherry-pick
  elif [[ -f $gitdir/REVERT_HEAD ]]; then op=revert
  elif [[ -f $gitdir/BISECT_LOG ]]; then op=bisect
  fi
  head=${head#refs/heads/}
  [[ $head == '(detached)' || -z $head ]] && head=${oid[1,8]}

  _prompt_esc $head
  local s="${_c_accent}${_i_branch}${REPLY}${_c_reset}"
  [[ $gitdir != $common ]] && s+=" ${_c_mute}wt${_c_reset}"
  segs+=$s; s=   # branch, then the status as its own segment: "  <item>", diff stat " <n>"
  (( behind )) && s+="  ${_c_warn}${_i_behind}${behind}${_c_reset}"
  (( ahead )) && s+="  ${_c_accent}${_i_ahead}${ahead}${_c_reset}"
  if (( files )); then
    s+="  ${_c_warn}${_i_dirty}${files}${_c_reset}"
    local st= ins=0 del=0
    (( files <= PROMPT_DIFF_MAX_FILES )) &&
      st=$(LC_ALL=C GIT_OPTIONAL_LOCKS=0 git diff --shortstat HEAD 2>/dev/null)
    [[ $st =~ '([0-9]+) insertion' ]] && ins=$match[1]
    [[ $st =~ '([0-9]+) deletion' ]] && del=$match[1]
    (( ins )) && s+=" ${_c_added}${_i_added}${ins}${_c_reset}"
    (( del )) && s+=" ${_c_removed}${_i_removed}${del}${_c_reset}"
  fi
  [[ -n $s ]] && segs+=${s#  }
  if [[ -n $op ]]; then
    s="${_c_warn}${op}${_c_reset}"
    (( conflicts )) && s+=" ${_c_fail}${_i_conflict}${conflicts} conflit${${conflicts:#1}:+s}${_c_reset}"
    segs+=$s
  fi

  # Background fetch, keyed on the common dir (all worktrees share refs); never mid-rebase.
  local file
  if [[ $PROMPT_AUTO_FETCH == true && -n $upstream && -z $op ]]; then
    _prompt_key fetch$common; file=$REPLY
    _prompt_read $file
    (( SPAWN && EPOCHSECONDS - _ts >= PROMPT_FETCH_TTL )) && _prompt_spawn $file _prompt_job_fetch $top $file
    [[ -d $file.lock ]] && pending+=$file
  fi

  [[ $head != ${oid[1,8]} && -z $op ]] && _git=($common $head $top)   # for {mr}
}

# MR/PR of the branch {git} found (_git, local to _prompt_render), from the cache.
function _prompt_seg_mr {
  [[ $PROMPT_SHOW_MR == true ]] && (( ${#_git} )) || return 0
  local common=$_git[1] head=$_git[2] top=$_git[3] file s
  _prompt_key mr$common@$head; file=$REPLY
  _prompt_read $file
  local num url draft state ci ttl=$PROMPT_MR_TTL
  IFS=$'\t' read -r num url draft state ci <<<$_data
  [[ $ci == (running|pending|created|preparing|waiting_for_resource|scheduled) ]] && ttl=20
  (( SPAWN && EPOCHSECONDS - _ts >= ttl )) && _prompt_spawn $file _prompt_job_mr $top $head $file
  [[ -d $file.lock ]] && pending+=$file
  [[ -n $num && $state == (opened|merged) ]] || return 0

  local icon=$_i_gitlab sigil='!'
  [[ $url == *github.com* ]] && icon=$_i_github sigil='#'
  s="${_c_mute}${icon}${_c_reset}"
  _prompt_esc $url
  # OSC 8 hyperlink (Ptyxis/VTE and the JetBrains terminal both support it).
  [[ $url == https://* ]] && s+="%{"$'\e]8;;'"${REPLY}"$'\e\\'"%}"
  s+="${_c_accent}${sigil}${num}${_c_reset}"
  [[ $url == https://* ]] && s+="%{"$'\e]8;;\e\\'"%}"
  (( draft )) && s+="  ${_c_mute}draft${_c_reset}"
  [[ $state == merged ]] && s+="  ${_c_mute}merged${_c_reset}"
  case $ci in
  ('') ;;
  (success) s+="  ${_c_ok}${_i_ci_ok}${_c_reset}" ;;
  (failed|canceled) s+="  ${_c_fail}${_i_ci_fail}${_c_reset}" ;;
  (skipped|manual) s+="  ${_c_mute}${_i_ci_skip}${_c_reset}" ;;
  (*) s+="  ${_c_run}${_i_ci_run}${_c_reset}" ;;
  esac
  segs+=$s
}

# Live Claude sessions, all of them. A session file counts only if its pid
# is alive AND started when the file says (pid reuse can't inflate the count).
# Builtins only: no fork.
typeset -g _prompt_proc=/proc
function _prompt_agents { # -> _prompt_n_agents, _prompt_n_busy
  _prompt_n_agents=0 _prompt_n_busy=0
  local f pid j stat start
  for f in ${CLAUDE_CONFIG_DIR:-$HOME/.claude}/sessions/*.json(N); do
    pid=${${f:t}%.json}
    [[ $pid == <-> ]] || continue
    if [[ -d $_prompt_proc ]]; then
      [[ -r $_prompt_proc/$pid/stat ]] || continue
      IFS= read -r -d '' j <$f
      [[ $j =~ '"procStart":"([0-9]+)"' ]] || continue
      start=$match[1]
      IFS= read -r stat <$_prompt_proc/$pid/stat
      stat=(${=${stat##*\) }})   # [20] = start time
      [[ $stat[20] == $start ]] || continue
    else
      # ponytail: no /proc (macOS): the pid alive is enough, a reused pid counts
      # until its file goes; compare procStart once its macOS format is known.
      kill -0 $pid 2>/dev/null || continue
      IFS= read -r -d '' j <$f
    fi
    (( _prompt_n_agents++ ))
    [[ $j == *'"status":"busy"'* ]] && (( _prompt_n_busy++ ))
  done
}

function _prompt_seg_agents {
  _prompt_agents
  (( _prompt_n_agents )) || return 0
  local s="${_c_agent}${_i_agent}${_prompt_n_agents} agent${${_prompt_n_agents:#1}:+s}${_c_reset}"
  (( _prompt_n_busy )) && s+="${_c_mute} · ${_c_reset}${_c_accent}${_prompt_n_busy} busy${_c_reset}"
  segs+=$s
}

function _prompt_seg_docker {
  (( $+commands[docker] )) || return 0
  local file count names
  _prompt_key docker; file=$REPLY
  _prompt_read $file
  (( SPAWN && EPOCHSECONDS - _ts >= PROMPT_DOCKER_TTL )) && _prompt_spawn $file _prompt_job_docker $file
  [[ -d $file.lock ]] && pending+=$file
  IFS=$'\t' read -r count names <<<$_data
  _prompt_esc $names
  [[ -n $count ]] && segs+="${_c_warn}${_i_docker}${count}${_c_reset} ${_c_mute}${REPLY}${_c_reset}"
}

#------------------------------------------------------------------------------

typeset -g _prompt_status=0 _prompt_title= _prompt_ran=0

function _prompt_seg_dir {
  _prompt_esc $PWD
  segs+="${_c_mute}${_i_dir}${_c_reset}${_c_primary}${REPLY}${_c_reset}"
}

# Claude quota, from the file ~/.claude/statusline-command.sh writes on each
# refresh ("5h% reset 7d% reset", epochs): local, so no job. A window whose
# reset has passed shows 0%, and so does one Claude Code doesn't report ("-"):
# no window open yet, nothing used in it. From PROMPT_QUOTA_RESET_AT %, the
# reset time follows (with the day when it is more than 24 h away).
function _prompt_seg_quota {
  [[ -r $PROMPT_QUOTA_FILE ]] || return 0
  local -a q=(${=${"$(<$PROMPT_QUOTA_FILE)"}}) r=() lbl=(5h 7d) col=($_c_quota_5h $_c_quota_7d)
  local i p c f
  integer g n=${#PROMPT_QUOTA_PALETTE}
  for i in 1 2; do
    p=${q[2*i-1]%.*}
    [[ $p == - ]] && p=0
    [[ $p == <-> ]] || continue
    (( q[2*i] && q[2*i] < EPOCHSECONDS )) && p=0
    (( g = (p > 100 ? 1.0 : p / 100.0) ** 1.3 * (n - 1) + 1.5 ))   # 1-based, rounded
    c=$'%{\e[38;5;'$PROMPT_QUOTA_PALETTE[g]'m%}'
    r+="${col[i]}${lbl[i]}${_c_reset} ${c}${p}%%${_c_reset}"
    (( p >= PROMPT_QUOTA_RESET_AT && q[2*i] > EPOCHSECONDS )) || continue
    f=%H:%M; (( q[2*i] - EPOCHSECONDS > 86400 )) && f="%a $f"
    strftime -s c $f $q[2*i]; _prompt_esc $c
    r[-1]+=" ${_c_mute}(${REPLY})${_c_reset}"
  done
  (( ${#r} )) && segs+=${(j:  :)r}
}

# Format -> _prompt_fmt_<side>_n (block names) and _t (texts, muted): t[1]
# before n[1], t[i] between n[i-1] and n[i], t[-1] after the last. Compiled
# again only when the format changes.
function _prompt_for_pwd { # ASSOC (keys: real paths) -> REPLY: value of the deepest key holding $PWD, or ''
  local k best= p=${PWD:A}   # real path: a project reached through a symlink (/tmp -> /private/tmp)
  for k in ${(Pk)1}; do   # a literal path, not a pattern
    [[ ( $p == $k || $p == $k/* ) && ${#k} -gt ${#best} ]] && best=$k
  done
  REPLY=; [[ -n $best ]] && k="$1[$best]" && REPLY=${(P)k}
}

# Settings come in layers, each over the one before; every PROMPT_* is rebuilt
# from them (_prompt_compose) at load, on a project switch and by shkit:
#   1. defaults: _prompt_defaults, then the blocks' own (plugins, prompt.d)
#   2. PROMPT_THEME's file: plugins/<plugin>/themes/<theme>.zsh
#   3. settings.sh and the environment, as they were when this file loaded
#   4. theme.zsh
#   5. the project file: projects/*.zsh, each with a line PROMPT_PROJECT_DIR=~/path,
#      for that directory and below (the deepest one wins)
# Files are sourced inside a function: plain assignments (typeset -g, not typeset).
typeset -g _prompt_local=${SHELL_LOCAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/shkit}
typeset -gA _prompt_projects   # dir -> file, read at load
typeset -g _prompt_project=- _prompt_layer_defaults= _prompt_layer_env= _prompt_theme_warned=
function _prompt_project_switch { # '-' in _prompt_project = compose again
  _prompt_for_pwd _prompt_projects
  [[ $REPLY == $_prompt_project ]] && return 0
  _prompt_project=$REPLY
  _prompt_compose $REPLY
}

function _prompt_snap { # -> REPLY: every PROMPT_* as `typeset -g …` (called in a function: -g)
  local -a n=(${(k)parameters[(I)PROMPT_*]})
  REPLY=; (( $#n )) && REPLY=$(typeset -p $n)   # no name = every parameter
}

function _prompt_layers { # THEME_FILE PROJECT_FILE (either may be '')
  unset -m 'PROMPT_*'; eval "$_prompt_layer_defaults"
  [[ -n $1 ]] && . $1
  eval "$_prompt_layer_env"
  [[ -r $_prompt_local/theme.zsh ]] && . $_prompt_local/theme.zsh
  [[ -n $2 ]] && . $2
}

function _prompt_compose { # [PROJECT_FILE] -> PROMPT_*, then compiled
  _prompt_layers '' $1
  local t=$PROMPT_THEME f=$_prompt_local/plugins/${PROMPT_THEME%%/*}/themes/${PROMPT_THEME#*/}.zsh
  if [[ -n $t ]]; then   # <plugin>/<theme>, no path of its own
    if [[ $t =~ '^[A-Za-z0-9_][A-Za-z0-9._-]*/[A-Za-z0-9_][A-Za-z0-9._-]*$' && -r $f ]]; then
      _prompt_layers $f $1
    elif [[ $t != $_prompt_theme_warned ]]; then   # once, not at every prompt
      _prompt_theme_warned=$t; print -ru2 -- "prompt: theme '$t' not found (shkit plugin list)"
    fi
  fi
  _prompt_theme
}

# Blocks: plugins/*/blocks/*.zsh, then prompt.d/*.zsh (same name = the later
# one wins, a built-in included). Each defines _prompt_seg_<name> (usable as
# {name}) and may set PROMPT_COLOR_<ROLE> / PROMPT_ICON_<NAME> defaults: layer 1.
function _prompt_load_blocks {
  local _f
  unset -m 'PROMPT_*'; _prompt_defaults
  for _f in $_prompt_local/plugins/*/blocks/*.zsh(N) $_prompt_local/prompt.d/*.zsh(N); do . $_f; done
  _prompt_snap; _prompt_layer_defaults=$REPLY
}

typeset -gA _prompt_fmt_src
function _prompt_compile { # SIDE FORMAT
  [[ ${_prompt_fmt_src[$1]-x} == $2 ]] && return 0
  _prompt_fmt_src[$1]=$2
  local f=$2 t
  local -a n=() tx=()
  while [[ $f =~ '\{([a-z0-9_]+)\}' ]]; do
    tx+=${f[1,MBEGIN-1]}; n+=$match[1]; f=${f[MEND+1,-1]}
  done
  tx+=$f
  local -a out=()
  for t in "${tx[@]}"; do _prompt_esc $t; out+=("${REPLY:+$_c_mute$REPLY$_c_reset}"); done
  set -A _prompt_fmt_$1_n "${n[@]}"; set -A _prompt_fmt_$1_t "${out[@]}"   # globals
}

function _prompt_line { # SIDE -> REPLY; segs/pending/SPAWN/sep from _prompt_render
  local -a n=(${(P)${:-_prompt_fmt_$1_n}}) t=("${(@P)${:-_prompt_fmt_$1_t}}") segs
  local out=$t[1] part shown=0 i
  for (( i = 1; i <= $#n; i++ )); do
    segs=()
    (( $+functions[_prompt_seg_$n[i]] )) && _prompt_seg_$n[i]
    part=${(pj:$sep:)segs}
    [[ -n $part ]] || continue
    (( shown++ )) && out+=$t[i]
    out+=$part
  done
  REPLY=$out; (( $#n )) && REPLY+=$t[-1]
}

# The right part ends the info line, so the input line holds only the $ (RPROMPT
# would sit on it): padded to $COLUMNS, dropped when both don't fit, rendered
# again on a resize (TRAPWINCH).
function _prompt_width { # PROMPT_TEXT -> REPLY: its width on screen
  emulate -L zsh -o extended_glob
  local s=${(%)1}
  s=${s//$'\e]8;;'[^$'\e']#$'\e\\'/}; s=${s//$'\e['[0-9;]#m/}
  REPLY=${(m)#s}
}

typeset -g _prompt_right=   # the right part, as rendered (shown or not)
function _prompt_render { # [SPAWN] -> PROMPT, _prompt_right, _prompt_pending
  local SPAWN=${1:-0} _ts _data
  _prompt_project_switch
  local -a pending=() _git=()
  _prompt_esc $PROMPT_SEPARATOR
  local sep="${_c_mute}${REPLY}${_c_reset}"
  _prompt_compile l $PROMPT_FORMAT; _prompt_compile r $PROMPT_RIGHT_FORMAT
  _prompt_line l; local l1=$REPLY
  _prompt_line r; _prompt_right=$REPLY
  (( ${#pending} )) && l1+=" ${_c_mute}${_i_refresh}${_c_reset}"
  if [[ -n $_prompt_right ]]; then
    _prompt_width $l1; local gap=$REPLY
    _prompt_width $_prompt_right
    (( gap = ${COLUMNS:-80} - gap - REPLY - 1 ))   # - 1: the last column would wrap
    (( gap >= 2 )) && l1+=${(l:gap:)}$_prompt_right
  fi
  RPROMPT=
  local chevron=$_c_primary
  (( _prompt_status )) && chevron=$'%{\e[1m%}'$_c_fail   # $ stays bold, like PRIMARY
  PROMPT="${l1}"$'\n'"${chevron}${_i_prompt}${_c_reset} "
  typeset -ga _prompt_pending=($pending)
}

# The watcher waits for the pending refreshes (each is a lock dir that its job
# removes), spinning the tab title while the shell sits at its prompt, then
# prints one line: zle wakes up (zle -F) and redraws the prompt in place.
function _prompt_watch { # FILE...
  local frames=($PROMPT_SPINNER) i=0 state running title f left
  state=$_prompt_cache/state.$$
  for (( ; i < 200; i++ )); do   # 20 s at most
    left=0
    for f; do [[ -d $f.lock ]] && left=1; done
    (( left )) || break
    if [[ $PROMPT_TITLE_SPINNER == true && -w $TTY ]]; then
      read -r running title <$state 2>/dev/null
      [[ $running == 0 ]] && print -n $'\e]0;'"$frames[i % $#frames + 1] $title · sync"$'\a' >$TTY
    fi
    sleep 0.1
  done
  read -r running title <$state 2>/dev/null
  [[ $running == 0 && -w $TTY ]] && print -n $'\e]0;'"$title"$'\a' >$TTY
  print done
}

function _prompt_winch { _prompt_render; zle && zle reset-prompt; }
(( $+functions[TRAPWINCH] )) || function TRAPWINCH { _prompt_winch }

function _prompt_async_done { # FD
  local fd=$1
  zle -F $fd; exec {fd}<&-
  [[ $fd == $_prompt_fd ]] && _prompt_fd=
  _prompt_render
  zle reset-prompt
}

function _prompt_precmd {
  _prompt_status=$?
  (( _prompt_ran )) && print   # blank line between a command's output and the next prompt
  _prompt_ran=0
  _prompt_title=$PWD   # the full path, even in $HOME (no ~)
  print -r -- "0 $_prompt_title" >| $_prompt_cache/state.$$
  print -n $'\e]0;'"$_prompt_title"$'\a'
  if [[ -n $_prompt_fd ]]; then   # the previous prompt's watcher is obsolete
    zle -F $_prompt_fd 2>/dev/null; exec {_prompt_fd}<&-; _prompt_fd=
  fi
  _prompt_render 1
  if (( ${#_prompt_pending} )); then
    exec {_prompt_fd}< <(_prompt_watch $_prompt_pending)
    zle -F $_prompt_fd _prompt_async_done
  fi
}

# A blank line sets a command's output apart.
function _prompt_preexec { _prompt_ran=1; print; print -r -- "1" >| $_prompt_cache/state.$$; }
function _prompt_zshexit { command rm -f $_prompt_cache/state.$$; }

autoload -Uz add-zsh-hook
add-zsh-hook precmd _prompt_precmd
add-zsh-hook preexec _prompt_preexec
add-zsh-hook zshexit _prompt_zshexit

function _prompt_projects_load { # projects/*.zsh -> _prompt_projects (dir -> file)
  local f d
  _prompt_projects=()
  for f in $_prompt_local/projects/*.zsh(N); do
    d=${${(M)${(f)"$(<$f)"}:#PROMPT_PROJECT_DIR=*}[1]#*=}   # first such line, read not run
    d=${${(Q)d}/#\~/$HOME}; [[ -n $d ]] && _prompt_projects[${d:A}]=$f
  done
}
_prompt_projects_load

# PROMPT_COLOR_* / PROMPT_ICON_* -> $_c_<role> (SGR in %{ %}) and $_i_<name>
# (%-escaped), built-in or from a block. Again at each _prompt_compose.
function _prompt_theme {
  local v
  unset -m '_c_*' '_i_*'
  typeset -g _c_reset=$'%{\e[0m%}'
  for v in ${(k)parameters[(I)PROMPT_COLOR_*]}; do
    typeset -g _c_${(L)v#PROMPT_COLOR_}=$'%{\e['${(P)v}'m%}'
  done
  for v in ${(k)parameters[(I)PROMPT_ICON_*]}; do
    _prompt_esc ${(P)v}; typeset -g _i_${(L)v#PROMPT_ICON_}=$REPLY
  done
  for v in dir branch gitlab github docker agent dirty; do   # followed by a space, if any
    typeset -g _i_$v=${(P)${:-_i_$v}:+${(P)${:-_i_$v}} }
  done
  PROMPT2="${_c_mute}>${_c_reset} "
}

function _prompt_init { _prompt_snap; _prompt_layer_env=$REPLY; _prompt_load_blocks; }   # a function: see _prompt_snap
_prompt_init
_prompt_project_switch   # composes the layers for $PWD

setopt NO_PROMPT_SUBST

. ${${(%):-%x}:A:h}/shkit.zsh   # the settings command
