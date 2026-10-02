# prompt.zsh — Claude Code–flavoured prompt: every fact on line 1, input on line 2.
#
#    ~/code/shop · SHOP-4966 wt · ⇣3  ⇡1   4 +120 −38 · !1234  ✓ ·  2 mysql8,nginx ↻
#   $                                        ✻ 4 agents · 1 busy · 5h 23%  7d 41%
#
# Theme (layout: SHKIT_FORMAT, colors, icons): ~/.config/shkit/theme.zsh, over a
# plugin's theme (see _prompt_compose). Colors are ROLES (those of ~/.claude/statusline-command.sh,
# plus AGENT = Claude orange), each an SGR code: SHKIT_COLOR_ACCENT='38;5;33'.
#
# Async: the synchronous path (every prompt) stays local, < 50 ms even on a large
# repository (35k files). Networked data (git fetch, MR/PR + CI + review, docker) is read from a
# cache under $XDG_RUNTIME_DIR; stale entries are refreshed by background
# jobs, and a watcher tells zle when they are done (zle -F), which redraws the
# prompt in place (zle reset-prompt) — no Enter needed. A muted ↻ = refresh in
# flight; the tab title spins meanwhile.
#
# Security: PROMPT_SUBST stays off and every dynamic text goes through
# _prompt_esc, so a branch named '$(…)' or '%F' is printed, never run.

# Here, not in zshrc: the prompt alone (sourced from your own zshrc) needs it too.
# A terminal launched from a GUI app (macOS) may start with no locale: zsh then
# can't read the prompt's icons ("character not in range") and miscounts its width.
# UTF-8 for characters only (messages, dates untouched); LC_ALL set = left alone.
[[ -z $LC_ALL && ${LC_CTYPE:-$LANG} != *.(UTF-8|utf-8|UTF8|utf8) ]] &&
  export LC_CTYPE=${${OSTYPE:#darwin*}:+C.}UTF-8   # macOS: UTF-8, Linux: C.UTF-8

zmodload zsh/datetime zsh/system
zmodload -F zsh/stat b:zstat   # zstat only: a plain load would shadow the stat binary
zmodload -F zsh/files b:zf_mkdir 2>/dev/null ||   # mkdir without a fork; zf_: the mkdir command stays
  function zf_mkdir { command mkdir "$@"; }       # a zsh built without zsh/files

# No XDG_RUNTIME_DIR on macOS: its $TMPDIR is per-user too.
typeset -g _prompt_cache=${XDG_RUNTIME_DIR:-${${TMPDIR:-/tmp}%/}/zsh-prompt-$UID}/zsh-prompt
command mkdir -p -m 700 $_prompt_cache 2>/dev/null
typeset -g _prompt_fd=   # watcher of the current refresh, if any

function _prompt_esc { REPLY=${1//\%/%%}; }   # dynamic text -> literal in PROMPT

# Defaults: the bottom layer, under plugin theme < settings.sh < theme.zsh < project
# (_prompt_compose). A theme sets the same names in ~/.config/shkit/theme.zsh.
function _prompt_defaults {
  : ${SHKIT_SHOW_MR:=true}        # MR/PR + CI (glab / gh, cached)
  : ${SHKIT_QUOTA_FILE:=${XDG_CACHE_HOME:-$HOME/.cache}/claude-quota}
  : ${SHKIT_QUOTA_RESET_AT:=80}   # from this %, the quota also shows when it resets
  : ${SHKIT_AUTO_FETCH:=true}     # background `git fetch`, for a true ⇣N
  : ${SHKIT_TITLE_SPINNER:=true}  # spinner in the tab title while a refresh runs
  : ${SHKIT_FETCH_TTL:=300}
  : ${SHKIT_MR_TTL:=120}          # 20 s while a pipeline is running
  : ${SHKIT_DOCKER_TTL:=30}
  : ${SHKIT_DIFF_MAX_FILES:=50}   # +/- skipped above this (556 files = 85 ms on a 35k-file repository)
  : ${SHKIT_TICKET_URL=}          # {ticket}: the tracker's URL, {id} = the ticket id (none = no block)
  : ${SHKIT_TICKET_PATTERN:='[A-Z]+-[0-9]+'}   # the ticket id in the branch name (a regex)
  : ${SHKIT_STACK=}               # {stack}: a docker compose project name (per project, none = no block)
  : ${SHKIT_DURATION_MIN:=3}      # {duration}: shown from this many seconds
  : ${SHKIT_NOTIFY:=true}         # a desktop notification when a long command ends
  : ${SHKIT_NOTIFY_AFTER:=30}     # …that ran this many seconds
  : ${SHKIT_NOTIFY_TIMEOUT=}      # ms it stays on screen (notify-send -t; none = the server's)
  # …but not for these (a command's name, after sudo / VAR=…): they are long because you use them
  (( ${+SHKIT_NOTIFY_IGNORE} )) ||
    SHKIT_NOTIFY_IGNORE=(vi vim nvim nano emacs less more man ssh mosh top htop btop watch tail tmux screen fzf
      fg bg psql mysql sqlite3 lazygit tig journalctl claude codex)

  # Layout: {block} placeholders and literal text (muted). Blocks: host (SSH / root
  # only), dir, git, ticket, mr, review (both need {git} before them), stack, docker
  # (anomalies only), duration, status (after a failure), agents (Claude sessions),
  # quota (Claude 5h / 7d). Text between two blocks is a separator: shown only
  # when a block on each side shows (the one before the next shown block wins).
  # Text before the first block / after the last one always shows. An unknown
  # name shows nothing. RIGHT = right-aligned at the end of the info line.
  : ${SHKIT_FORMAT='{host} · {dir} · {git} · {ticket} · {mr}  {review} · {stack} · {docker} · {duration} · {status}'}
  : ${SHKIT_RIGHT_FORMAT='{agents} · {quota}'}
  : ${SHKIT_SEPARATOR:=' · '}   # inside a block: git = branch · status · rebase

  : ${SHKIT_COLOR_PRIMARY:='1;32'}     ${SHKIT_COLOR_ACCENT:='36'}
  : ${SHKIT_COLOR_MUTE:='38;5;248'}    ${SHKIT_COLOR_WARN:='38;5;208'}
  : ${SHKIT_COLOR_ADDED:='38;5;114'}   ${SHKIT_COLOR_REMOVED:='38;5;174'}
  : ${SHKIT_COLOR_OK:='32'}          ${SHKIT_COLOR_FAIL:='31'}
  : ${SHKIT_COLOR_RUN:='34'}         ${SHKIT_COLOR_AGENT:='38;5;173'}
  : ${SHKIT_COLOR_QUOTA_5H:='38;5;141'} ${SHKIT_COLOR_QUOTA_7D:='38;5;99'}   # labels, as the statusline (not bold)
  # Quota % gradient (256-color), low -> high, ratio^1.3 — the statusline's QUOTA_PALETTE.
  (( ${+SHKIT_QUOTA_PALETTE} )) || SHKIT_QUOTA_PALETTE=(108 108 150 150 185 185 227 227 221 221 215 215 209 209 167)

  # Icons (Nerd Font for dir/gitlab/github/docker). Set one to '' to drop it.
  # `=` not `:=`: an icon set empty stays empty.
  : ${SHKIT_ICON_DIR=}        ${SHKIT_ICON_BRANCH=}      ${SHKIT_ICON_GITLAB=$'\uf296'}
  : ${SHKIT_ICON_GITHUB=$'\uf09b'}  ${SHKIT_ICON_DOCKER=$'\uf308'}  ${SHKIT_ICON_AGENT=✻}
  : ${SHKIT_ICON_BEHIND=⇣}  ${SHKIT_ICON_AHEAD=⇡}  ${SHKIT_ICON_DIRTY=$'\uf044'}
  : ${SHKIT_ICON_ADDED=+}   ${SHKIT_ICON_REMOVED=−}  ${SHKIT_ICON_CONFLICT=✗}
  : ${SHKIT_ICON_CI_OK=✓}   ${SHKIT_ICON_CI_FAIL=✗}  ${SHKIT_ICON_CI_SKIP=○}  ${SHKIT_ICON_CI_RUN=●}
  : ${SHKIT_ICON_REFRESH=↻}  ${SHKIT_ICON_PROMPT='$'}  ${SHKIT_ICON_STATUS=✗}  ${SHKIT_ICON_HOST=}
  : ${SHKIT_ICON_TICKET=$''}  ${SHKIT_ICON_APPROVED=$''}  ${SHKIT_ICON_THREADS=$''}
  : ${SHKIT_ICON_DURATION=$''}
  (( ${+SHKIT_SPINNER} )) || SHKIT_SPINNER=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)   # tab title
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
# The lock is taken here, before the fork: the caller's `[[ -d FILE.lock ]]` right
# after must see it, or the prompt neither shows ↻ nor redraws when the job ends.
function _prompt_spawn {
  local file=$1; shift
  _prompt_locked $file && return 0
  zf_mkdir $file.lock 2>/dev/null || return 0
  {
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

# Approvals and unresolved threads of an open MR / PR (its number and URL: {mr}'s cache).
# Output: "<approvals>\t<unresolved threads>"
function _prompt_job_review { # TOPLEVEL NUMBER URL FILE
  local data= a t
  cd $1 || return
  if [[ $3 == *github.com* ]]; then
    data=$(_prompt_timeout 5 gh api graphql -F owner='{owner}' -F name='{repo}' -F n=$2 -f query='
      query($owner: String!, $name: String!, $n: Int!) { repository(owner: $owner, name: $name) {
        pullRequest(number: $n) { latestReviews(first: 100) { nodes { state } }
                                  reviewThreads(first: 100) { nodes { isResolved } } } } }' --jq '
      .data.repository.pullRequest | [ ([.latestReviews.nodes[] | select(.state == "APPROVED")] | length),
                                       ([.reviewThreads.nodes[] | select(.isResolved | not)] | length) ] | @tsv' 2>/dev/null)
  else
    a=$(_prompt_timeout 5 glab api "projects/:id/merge_requests/$2/approvals" 2>/dev/null | jq -r '.approved_by | length')
    t=$(_prompt_timeout 5 glab api "projects/:id/merge_requests/$2/discussions?per_page=100" 2>/dev/null |
      jq -r '[.[] | select(.notes[0].resolvable) | select(.notes | any(.resolved | not))] | length')
    data=$a$'\t'$t
  fi
  [[ $data == <->$'\t'<-> ]] || data=
  _prompt_write $4 $data
}

# One compose project: its services, how many are up, how many are down or unhealthy.
# A one-off run, or an init container exited with 0, doesn't count.
# Output: "<services>\t<up>\t<bad>\t<first bad names>"
function _prompt_job_stack { # PROJECT FILE
  local data
  data=$(_prompt_timeout 3 docker ps -a --filter label=com.docker.compose.project=$1 \
    --format '{{.Label "com.docker.compose.oneoff"}}	{{.State}}	{{.Status}}	{{.Names}}' |
    awk -F'\t' '
      $1 == "True" { next }
      { n++ }
      $2 == "running" && $3 !~ /unhealthy/ { up++; next }
      $2 == "exited" && $3 ~ /^Exited \(0\)/ { next }
      { if (++c <= 2) bad = bad (bad ? "," : "") $4 }
      END { if (n) printf "%d\t%d\t%d\t%s", n, up, c, bad }')
  _prompt_write $2 $data
}

#------------------------------------------------------------------------------
# Segments (synchronous, local): _prompt_seg_<name> appends its text to
# `segs`, and to `pending` the cache files whose refresh is in flight (watched
# for redraw). A new segment = a new _prompt_seg_<name> + its {name} in SHKIT_FORMAT.
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
    (( files <= SHKIT_DIFF_MAX_FILES )) &&
      st=$(LC_ALL=C GIT_OPTIONAL_LOCKS=0 git diff --shortstat HEAD 2>/dev/null)
    [[ $st =~ '([0-9]+) insertion' ]] && ins=$match[1]
    [[ $st =~ '([0-9]+) deletion' ]] && del=$match[1]
    (( ins )) && s+=" ${_c_added}${_i_added}${ins}${_c_reset}"
    (( del )) && s+=" ${_c_removed}${_i_removed}${del}${_c_reset}"
  fi
  [[ -n $s ]] && segs+=${s#  }
  if [[ -n $op ]]; then
    s="${_c_warn}${op}${_c_reset}"
    (( conflicts )) && s+=" ${_c_fail}${_i_conflict}${conflicts} conflict${${conflicts:#1}:+s}${_c_reset}"
    segs+=$s
  fi

  # Background fetch, keyed on the common dir (all worktrees share refs); never mid-rebase.
  local file
  if [[ $SHKIT_AUTO_FETCH == true && -n $upstream && -z $op ]]; then
    _prompt_key fetch$common; file=$REPLY
    _prompt_read $file
    (( SPAWN && EPOCHSECONDS - _ts >= SHKIT_FETCH_TTL )) && _prompt_spawn $file _prompt_job_fetch $top $file
    [[ -d $file.lock ]] && pending+=$file
  fi

  [[ $head != ${oid[1,8]} && -z $op ]] && _git=($common $head $top)   # for {mr}
}

# MR/PR of the branch {git} found (_git, local to _prompt_render), from the cache.
function _prompt_seg_mr {
  [[ $SHKIT_SHOW_MR == true ]] && (( ${#_git} )) || return 0
  local common=$_git[1] head=$_git[2] top=$_git[3] file s
  _prompt_key mr$common@$head; file=$REPLY
  _prompt_read $file
  local num url draft state ci ttl=$SHKIT_MR_TTL
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

# The ticket id in the branch name (SHOP-42), a link to SHKIT_TICKET_URL.
function _prompt_seg_ticket {
  setopt localoptions no_bash_rematch
  local MATCH MBEGIN MEND url id
  (( ${#_git} )) && [[ -n $SHKIT_TICKET_URL ]] || return 0
  { [[ $_git[2] =~ $SHKIT_TICKET_PATTERN ]] } 2>/dev/null || return 0   # a bad regex: no block, no error at each prompt
  id=$MATCH
  _prompt_esc ${SHKIT_TICKET_URL//\{id\}/$id}; url=$REPLY
  _prompt_esc $id
  segs+="${_c_mute}${_i_ticket}${_c_reset}%{"$'\e]8;;'"${url}"$'\e\\'"%}${_c_accent}${REPLY}${_c_reset}%{"$'\e]8;;\e\\'"%}"
}

# Approvals and unresolved threads of the open MR / PR {mr} found (same TTL).
function _prompt_seg_review {
  [[ $SHKIT_SHOW_MR == true ]] && (( ${#_git} )) || return 0
  local num url state file a t s= cli=glab
  _prompt_key mr$_git[1]@$_git[2]; _prompt_read $REPLY
  IFS=$'\t' read -r num url _ state _ <<<$_data
  [[ $num == <-> && $state == opened ]] || return 0
  [[ $url == *github.com* ]] && cli=gh
  (( $+commands[$cli] )) || return 0
  [[ $cli == gh ]] || (( $+commands[jq] )) || return 0   # glab's answers go through jq
  _prompt_key review$_git[1]@$num; file=$REPLY
  _prompt_read $file
  (( SPAWN && EPOCHSECONDS - _ts >= SHKIT_MR_TTL )) && _prompt_spawn $file _prompt_job_review $_git[3] $num $url $file
  [[ -d $file.lock ]] && pending+=$file
  IFS=$'\t' read -r a t <<<$_data
  (( a )) && s="${_c_ok}${_i_approved}${a}${_c_reset}"
  (( t )) && s+="${s:+  }${_c_warn}${_i_threads}${t}${_c_reset}"
  [[ -n $s ]] && segs+=$s
}

# The compose project SHKIT_STACK: "shop ✓" all up, "shop 2 ✗ db,web", "shop off".
function _prompt_seg_stack {
  [[ -n $SHKIT_STACK ]] && (( $+commands[docker] )) || return 0
  local file n up bad names s
  _prompt_key stack$SHKIT_STACK; file=$REPLY
  _prompt_read $file
  (( SPAWN && EPOCHSECONDS - _ts >= SHKIT_DOCKER_TTL )) && _prompt_spawn $file _prompt_job_stack $SHKIT_STACK $file
  [[ -d $file.lock ]] && pending+=$file
  (( _ts )) || return 0   # never read yet: ↻ only
  IFS=$'\t' read -r n up bad names <<<$_data
  _prompt_esc $SHKIT_STACK; s="${_c_mute}${_i_docker}${REPLY}${_c_reset} "
  if (( ! up )); then s+="${_c_mute}off${_c_reset}"
  elif (( bad )); then _prompt_esc $names; s+="${_c_warn}${bad} ${_i_ci_fail}${_c_reset} ${_c_mute}${REPLY}${_c_reset}"
  else s+="${_c_ok}${_i_ci_ok}${_c_reset}"
  fi
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
  (( SPAWN && EPOCHSECONDS - _ts >= SHKIT_DOCKER_TTL )) && _prompt_spawn $file _prompt_job_docker $file
  [[ -d $file.lock ]] && pending+=$file
  IFS=$'\t' read -r count names <<<$_data
  _prompt_esc $names
  [[ -n $count ]] && segs+="${_c_warn}${_i_docker}${count}${_c_reset} ${_c_mute}${REPLY}${_c_reset}"
}

#------------------------------------------------------------------------------

typeset -g _prompt_status=0 _prompt_title= _prompt_ran=0 _prompt_start=0 _prompt_cmd=
typeset -gi _prompt_elapsed=0   # seconds the last command took; 0 after an empty line

function _prompt_seg_dir {
  _prompt_esc $PWD
  segs+="${_c_mute}${_i_dir}${_c_reset}${_c_primary}${REPLY}${_c_reset}"
}

# user@host, over SSH or as root only (the machine you are on is then worth a look).
function _prompt_seg_host {
  [[ -n $SSH_CONNECTION$SSH_TTY ]] || (( EUID == 0 )) || return 0
  local c=$_c_warn; (( EUID == 0 )) && c=$_c_fail
  _prompt_esc $USERNAME@${HOST%%.*}
  segs+="${_c_mute}${_i_host}${_c_reset}${c}${REPLY}${_c_reset}"
}

function _prompt_human { # SECONDS -> REPLY: 45s, 1m05s, 2h03m (integers: no locale's decimal comma)
  integer s=$1
  if (( s < 60 )); then REPLY=${s}s
  elif (( s < 3600 )); then printf -v REPLY '%dm%02ds' $(( s / 60 )) $(( s % 60 ))
  else printf -v REPLY '%dh%02dm' $(( s / 3600 )) $(( s % 3600 / 60 ))
  fi
}

# How long the last command ran, from SHKIT_DURATION_MIN seconds (measured once, in precmd).
function _prompt_seg_duration {
  (( _prompt_elapsed >= SHKIT_DURATION_MIN && _prompt_elapsed )) || return 0
  _prompt_human $_prompt_elapsed
  segs+="${_c_mute}${_i_duration}${_c_reset}${_c_accent}${REPLY}${_c_reset}"
}

# The last command's exit status, if it failed: "✗ 2", or the signal that ended it: "✗ INT".
function _prompt_seg_status {
  (( _prompt_status )) || return 0
  local s=$_prompt_status
  (( s > 128 && s - 127 <= $#signals - 2 )) && s=$signals[s-127]   # [1] = EXIT (0); the last two: ZERR, DEBUG
  segs+="${_c_fail}${_i_status}${s}${_c_reset}"
}

# A long command finished: a desktop notification (notify-send; macOS: osascript), else
# (over SSH, or neither) the terminal bell. Its name only, never its line: a
# notification history would keep a token typed in it. No check that the tab is out
# of sight: no terminal tells it portably (focus reports would reach the running command).
function _prompt_notify {
  [[ $SHKIT_NOTIFY == true ]] && (( SHKIT_NOTIFY_AFTER > 0 && _prompt_elapsed >= SHKIT_NOTIFY_AFTER )) || return 0
  (( _prompt_status > 128 )) && [[ $signals[_prompt_status-127] == (TSTP|INT) ]] && return 0   # ^Z, ^C: you are here
  # The command of each part of the line (aliases already expanded by preexec), past
  # sudo, VAR=…, options and ( { !: one ignored = no notification; shown: the first but cd.
  local c title body first=1
  local -a names=() ign=(${=SHKIT_NOTIFY_IGNORE})   # ${=…}: a list typed as one string works too
  for c in ${(z)_prompt_cmd}; do
    [[ $c == (';'|'&&'|'||'|'|'|'|&'|'&'|'&!'|'&|') ]] && { first=1; continue }
    (( first )) && [[ $c != (sudo|doas|command|builtin|exec|time|nohup|noglob|nocorrect|env|nice|'('|'{'|'!'|'[['|-*|*=*) ]] || continue
    (( $+commands[$c] || $+aliases[$c] || $+functions[$c] || $+builtins[$c] )) || [[ $c == */* ]] || continue
    names+=${c:t}; first=0
  done
  ign=(${names:*ign})   # the ignored ones among them (nested, ${#${…:*…}} counts nothing)
  (( $#names && ! $#ign )) || return 0
  c=${${names:#(cd|pushd|popd|source|.)}[1]:-$names[1]}
  _prompt_human $_prompt_elapsed
  local icon=emblem-default   # the server's colors: a green check, a red error (freedesktop names)
  if (( _prompt_status )); then title="✗ $c failed · exit $_prompt_status" icon=dialog-error; else title="✓ $c done"; fi
  if [[ -z $SSH_CONNECTION && -n $DISPLAY$WAYLAND_DISPLAY ]] && (( $+commands[notify-send] )); then
    body="<b>$REPLY</b>  ·  ${${${PWD//&/&amp;}//</&lt;}//>/&gt;}"   # the body is markup: the path escaped
    notify-send -a shellkit -i $icon ${SHKIT_NOTIFY_TIMEOUT:+-t} ${SHKIT_NOTIFY_TIMEOUT:+$SHKIT_NOTIFY_TIMEOUT} \
      -- $title $body </dev/null >/dev/null 2>&1 &!
  elif [[ -z $SSH_CONNECTION ]] && (( $+commands[osascript] )); then   # the text as arguments, never as AppleScript
    osascript -e 'on run argv' \
      -e 'display notification (item 3 of argv) with title (item 1 of argv) subtitle (item 2 of argv)' -e 'end run' \
      shellkit $title "$REPLY  ·  $PWD" </dev/null >/dev/null 2>&1 &!
  else
    print -n $'\a'
  fi
}

# Claude quota, from the file ~/.claude/statusline-command.sh writes on each
# refresh ("5h% reset 7d% reset", epochs): local, so no job. A window whose
# reset has passed shows 0%, and so does one Claude Code doesn't report ("-"):
# no window open yet, nothing used in it. From SHKIT_QUOTA_RESET_AT %, the
# reset time follows (with the day when it is more than 24 h away).
function _prompt_seg_quota {
  [[ -r $SHKIT_QUOTA_FILE ]] || return 0
  local -a q=(${=${"$(<$SHKIT_QUOTA_FILE)"}}) r=() lbl=(5h 7d) col=($_c_quota_5h $_c_quota_7d)
  local i p c f
  integer g n=${#SHKIT_QUOTA_PALETTE}
  for i in 1 2; do
    p=${q[2*i-1]%.*}
    [[ $p == - ]] && p=0
    [[ $p == <-> ]] || continue
    (( q[2*i] && q[2*i] < EPOCHSECONDS )) && p=0
    (( g = (p > 100 ? 1.0 : p / 100.0) ** 1.3 * (n - 1) + 1.5 ))   # 1-based, rounded
    c=$'%{\e[38;5;'$SHKIT_QUOTA_PALETTE[g]'m%}'
    r+="${col[i]}${lbl[i]}${_c_reset} ${c}${p}%%${_c_reset}"
    (( p >= SHKIT_QUOTA_RESET_AT && q[2*i] > EPOCHSECONDS )) || continue
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

# Settings come in layers, each over the one before; every SHKIT_* is rebuilt
# from them (_prompt_compose) at load, on a project switch and by shkit:
#   1. defaults: _prompt_defaults, then the blocks' own (plugins, prompt.d)
#   2. SHKIT_THEME's file: plugins/<plugin>/themes/<theme>.zsh
#   3. settings.sh and the environment, as they were when this file loaded
#   4. theme.zsh
#   5. the project file: projects/*.zsh, each with a line SHKIT_PROJECT_DIR=~/path,
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

# shellkit 1.0 named its settings PROMPT_*: an old name still works, as its SHKIT_* in the
# same layer. shkit renames them in a file it edits, install-local.sh everywhere. Never
# bash's or zsh's own (PROMPT_COMMAND, PROMPT_EOL_MARK…): the one list, for all of them.
typeset -g _prompt_foreign='PROMPT_(COMMAND|DIRTRIM|EOL_MARK)'
typeset -ga _prompt_mirrors=()
function _prompt_compat {
  local v n
  for v in ${(k)parameters[(I)PROMPT_*]:#${~_prompt_foreign}}; do
    n=SHKIT_${v#PROMPT_}; unset $n
    if [[ ${(tP)v} == array* ]]; then set -A $n "${(@P)v}"; else typeset -g $n=${(P)v}; fi
    unset $v
  done
}

# …and a 1.0 block reading $PROMPT_<X> as it renders still finds it: a copy of each
# SHKIT_<X> once composed, dropped before the next compose (-u).
function _prompt_mirror { # [-u]
  local v n
  (( $#_prompt_mirrors )) && unset $_prompt_mirrors; _prompt_mirrors=()
  [[ $1 == -u ]] && return
  for v in ${(k)parameters[(I)SHKIT_*]:#SHKIT_(AUTO_UPDATE|UPDATE_TTL)}; do   # those two: never PROMPT_*
    n=PROMPT_${v#SHKIT_}
    [[ $n == ${~_prompt_foreign} ]] && continue
    if [[ ${(tP)v} == array* ]]; then set -A $n "${(@P)v}"; else typeset -g $n=${(P)v}; fi
    _prompt_mirrors+=$n
  done
}

function _prompt_snap { # -> REPLY: every SHKIT_* as `typeset -g …` (called in a function: -g)
  local -a n=(${(k)parameters[(I)SHKIT_*]})
  REPLY=; (( $#n )) && REPLY=$(typeset -p $n)   # no name = every parameter
}

function _prompt_layers { # THEME_FILE PROJECT_FILE (either may be '')
  _prompt_mirror -u; unset -m 'SHKIT_*'; eval "$_prompt_layer_defaults"
  [[ -n $1 ]] && { . $1; _prompt_compat }
  eval "$_prompt_layer_env"
  [[ -r $_prompt_local/theme.zsh ]] && { . $_prompt_local/theme.zsh; _prompt_compat }
  [[ -n $2 ]] && { . $2; _prompt_compat }
}

function _prompt_compose { # [PROJECT_FILE] -> SHKIT_*, then compiled
  _prompt_layers '' $1
  local t=$SHKIT_THEME f=$_prompt_local/plugins/${SHKIT_THEME%%/*}/themes/${SHKIT_THEME#*/}.zsh
  if [[ -n $t ]]; then   # <plugin>/<theme>, no path of its own
    if [[ $t =~ '^[A-Za-z0-9_][A-Za-z0-9._-]*/[A-Za-z0-9_][A-Za-z0-9._-]*$' && -r $f ]]; then
      _prompt_layers $f $1
    elif [[ $t != $_prompt_theme_warned ]]; then   # once, not at every prompt
      _prompt_theme_warned=$t; print -ru2 -- "prompt: theme '$t' not found (shkit plugin list)"
    fi
  fi
  _prompt_theme; _prompt_mirror
}

# Blocks: plugins/*/blocks/*.zsh, then prompt.d/*.zsh (same name = the later
# one wins, a built-in included). Each defines _prompt_seg_<name> (usable as
# {name}) and may set SHKIT_COLOR_<ROLE> / SHKIT_ICON_<NAME> defaults: layer 1.
function _prompt_load_blocks {
  local _f
  _prompt_mirror -u; unset -m 'SHKIT_*'; _prompt_defaults
  for _f in $_prompt_local/plugins/*/blocks/*.zsh(N) $_prompt_local/prompt.d/*.zsh(N); do . $_f; _prompt_compat; done
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
  _prompt_esc $SHKIT_SEPARATOR
  local sep="${_c_mute}${REPLY}${_c_reset}"
  _prompt_compile l $SHKIT_FORMAT; _prompt_compile r $SHKIT_RIGHT_FORMAT
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
  local frames=($SHKIT_SPINNER) i=0 state running title f left
  state=$_prompt_cache/state.$$
  for (( ; i < 200; i++ )); do   # 20 s at most
    left=0
    for f; do [[ -d $f.lock ]] && left=1; done
    (( left )) || break
    if [[ $SHKIT_TITLE_SPINNER == true && -w $TTY ]]; then
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
  _prompt_elapsed=0   # measured once here: a redraw (async, resize) doesn't touch it
  if (( _prompt_start )); then
    (( _prompt_elapsed = EPOCHREALTIME - _prompt_start )); _prompt_start=0
    _prompt_notify
  fi
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
function _prompt_preexec { # TYPED EXPANDED FULL
  _prompt_ran=1 _prompt_start=$EPOCHREALTIME _prompt_cmd=$2   # $2: aliases expanded
  print; print -r -- "1" >| $_prompt_cache/state.$$
}
function _prompt_zshexit { command rm -f $_prompt_cache/state.$$; }

autoload -Uz add-zsh-hook
add-zsh-hook precmd _prompt_precmd
add-zsh-hook preexec _prompt_preexec
add-zsh-hook zshexit _prompt_zshexit

function _prompt_projects_load { # projects/*.zsh -> _prompt_projects (dir -> file)
  local f d
  _prompt_projects=()
  for f in $_prompt_local/projects/*.zsh(N); do
    d=${${(M)${(f)"$(<$f)"}:#(SHKIT|PROMPT)_PROJECT_DIR=*}[1]#*=}   # first such line, read not run
    d=${${(Q)d}/#\~/$HOME}; [[ -n $d ]] && _prompt_projects[${d:A}]=$f
  done
}
_prompt_projects_load

# SHKIT_COLOR_* / SHKIT_ICON_* -> $_c_<role> (SGR in %{ %}) and $_i_<name>
# (%-escaped), built-in or from a block. Again at each _prompt_compose.
function _prompt_theme {
  local v
  unset -m '_c_*' '_i_*'
  typeset -g _c_reset=$'%{\e[0m%}'
  for v in ${(k)parameters[(I)SHKIT_COLOR_*]}; do
    typeset -g _c_${(L)v#SHKIT_COLOR_}=$'%{\e['${(P)v}'m%}'
  done
  for v in ${(k)parameters[(I)SHKIT_ICON_*]}; do
    _prompt_esc ${(P)v}; typeset -g _i_${(L)v#SHKIT_ICON_}=$REPLY
  done
  for v in dir branch gitlab github docker agent dirty ticket approved threads duration status host; do   # followed by a space, if any
    typeset -g _i_$v=${(P)${:-_i_$v}:+${(P)${:-_i_$v}} }
  done
  PROMPT2="${_c_mute}>${_c_reset} "
}

function _prompt_init { _prompt_compat; _prompt_snap; _prompt_layer_env=$REPLY; _prompt_load_blocks; }   # a function: see _prompt_snap
_prompt_init
_prompt_project_switch   # composes the layers for $PWD

setopt NO_PROMPT_SUBST

. ${${(%):-%x}:A:h}/shkit.zsh   # the settings command
