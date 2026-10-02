# shkit — change the prompt settings without writing shell by hand.
# Sourced by prompt.zsh. It edits $SHELL_LOCAL_DIR/theme.zsh (global) or the
# current project's file (-p), then applies the change to this shell.
#
#   shkit show                    active project, settings in its files, blocks
#   shkit list                    every SHKIT_* in effect here
#   shkit set [-p] NAME VALUE…    NAME = format, right_format, color_accent,
#                                     icon_dirty, show_mr… (SHKIT_<NAME>); several
#                                     VALUEs = an array (quota_palette, spinner)
#   shkit unset [-p] NAME
#   shkit project [DIR]           a settings file for DIR and below (default: the
#                                     repo, its worktrees included; else $PWD)
#   shkit edit [-p]               open the file in $EDITOR
#   shkit plugin add [-y] URL     clone a plugin: a git repository whose plugin.json
#                                     follows zsh/plugin/schema.json (blocks / themes)
#   shkit plugin update [-y] [NAME]    fetch, show what comes, fast-forward
#   shkit plugin remove NAME | list
#   shkit plugin new NAME [DIR]   start a plugin repository: plugin.json + git init
#   shkit plugin new-block NAME [DESCRIPTION] | new-theme NAME [DESCRIPTION]
#                                     in a plugin repository: the file + its plugin.json entry
#   shkit plugin check [DIR]      the layout, as add / update check it (DIR: default here)
#   shkit set theme PLUGIN/THEME  a plugin's theme, under theme.zsh (-p: one project)
#   shkit update [-y]             shellkit itself, to its latest release (branch release);
#                                     also done in the background at startup, daily
#   shkit doctor                  checks the setup: versions, locale, font, tools, files, plugins
#
# Values are written quoted: a file it writes never runs what a value contains.
# A plugin IS code run by every shell: nothing is fetched unless asked, and each
# add / update shows what it brings and asks first (-y: don't ask).

function shkit {
  local d=${SHELL_LOCAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/shkit} cmd=$1 file name
  (( $# )) && shift
  local proj=0; [[ $1 == -p ]] && { proj=1; shift }
  if (( proj )); then
    _prompt_for_pwd _prompt_projects; file=$REPLY   # $PWD's, even before the next prompt
    [[ -n $file ]] || { print -u2 "shkit: no project here; create one with: shkit project"; return 1 }
  else
    file=$d/theme.zsh
  fi
  case $cmd in
  (set|unset)
    name=${(U)1//[.-]/_}; name=SHKIT_${${name#SHKIT_}#PROMPT_}
    [[ $name =~ '^SHKIT_[A-Z0-9_]+$' && $name != SHKIT_PROJECT_DIR ]] ||
      { print -u2 "shkit: bad name '$1'"; return 1 }
    shift
    local line=
    if [[ $cmd == set ]]; then
      (( $# )) || { print -u2 "shkit: set $name to what?"; return 1 }
      if (( $# > 1 )); then line="$name=(${(j: :)${(q+)@}})"; else line="$name=${(q+)1}"; fi
    fi
    _shkit_write $file $name $line || return
    _shkit_reset ;;
  (project)
    local dir=$1
    [[ -n $dir ]] || { dir=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) && dir=${dir:h} }
    dir=${${dir:-$PWD}:A}
    file=$_prompt_projects[$dir]
    if [[ -z $file ]]; then
      file=$d/projects/${dir:t}.zsh
      [[ -e $file ]] && file=$d/projects/${dir:t}-${#_prompt_projects}.zsh
      command mkdir -p $d/projects
      print -rl -- "# Prompt settings for ${dir/#$HOME/~} and below, over theme.zsh." \
        "# Change them with: shkit set -p NAME VALUE (see: shkit list)" \
        "SHKIT_PROJECT_DIR=${(q-)${dir/#$HOME/~}}" >| $file
      _prompt_projects_load; _shkit_reset
    fi
    print -r -- ${file/#$HOME/~} ;;
  (edit)
    ${=${VISUAL:-${EDITOR:-vi}}} $file || return
    _prompt_projects_load; _shkit_reset ;;
  (show)
    local f
    print -r -- "project: ${${_prompt_project/#$HOME/~}:-none}"
    for f in $d/theme.zsh $_prompt_project; do
      [[ -r $f ]] || continue
      print -r -- "${f/#$HOME/~}:"
      print -rl -- "  "${^${(M)${(f)"$(<$f)"}:#(SHKIT|PROMPT)_*}}
    done
    print -r -- "blocks: ${(j: :)${(@)${(@ok)functions[(I)_prompt_seg_*]}#_prompt_seg_}}"
    print -r -- "themes: ${(j: :)${(@)${(@f)$(_shkit_themes)}:-none}}" ;;
  (list)
    typeset -m 'SHKIT_*' ;;
  (plugin)
    _shkit_plugin $d/plugins "$@" ;;
  (update)
    _shkit_update "$@" ;;
  (doctor)
    _shkit_doctor ;;
  (*)
    print -u2 "usage: shkit show | list | set [-p] NAME VALUE… | unset [-p] NAME | project [DIR] | edit [-p] | plugin add|update|remove|list|new|new-block|new-theme|check | update [-y] | doctor"
    return 1 ;;
  esac
}

function _shkit_write { # FILE NAME [LINE] — NAME's line replaced (or appended); no LINE = removed
  local f=$1 n=$2 l=$3
  local -a lines=()
  setopt localoptions extendedglob
  [[ -r $f ]] && lines=("${(@f)$(<$f)}") &&
    lines=("${(@)lines//(#b)((#s)|[[:space:]\#])PROMPT_([A-Z0-9_]##=)/$match[1]SHKIT_$match[2]}") &&   # 1.0's names: renamed,
    lines=("${(@)lines//(#b)SHKIT_(${~_prompt_foreign#PROMPT_})=/PROMPT_$match[1]=}")                       # not bash's or zsh's
  integer i=${lines[(i)$n=*]}
  if [[ -z $l ]]; then lines=("${(@)lines:#$n=*}")
  elif (( i <= $#lines )); then lines[i]=$l
  else lines+=($l)
  fi
  [[ -d ${f:h} ]] || command mkdir -p -m 700 ${f:h} || return   # prompt only: no install-local.sh ran
  print -rl -- "${lines[@]}" >| $f
}

function _shkit_reset { # every layer read again, applied now
  _prompt_project=-; _prompt_project_switch
}

function _shkit_themes { # -> one PLUGIN/THEME per line
  local f
  for f in ${SHELL_LOCAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/shkit}/plugins/*/themes/*.zsh(N); do
    print -r -- ${f:h:h:t}/${f:t:r}
  done
}

function _shkit_url { # TEXT -> REPLY, each URL without its user:password@ (a token must not be printed)
  setopt localoptions extendedglob
  REPLY=${1//:\/\/[^\/@[:space:]]##@/://}
}

function _shkit_ask { # YES QUESTION — YES=1 or a y from the terminal
  (( $1 )) && return 0
  read -q "?$2 [y/N] " || { print; return 1 }
  print
}

function _shkit_plugin { # ROOT SUB [-y] ARGS…
  local root=$1 sub=$2 name dir url f yes=0
  shift 2
  [[ $1 == -y ]] && { yes=1; shift }
  local re='^[A-Za-z0-9_][A-Za-z0-9._-]*$'   # a directory name: no /, no leading . or -
  case $sub in
  (add)
    (( $# == 1 )) || { print -u2 "usage: shkit plugin add [-y] URL"; return 1 }
    url=$1 dir=$root.new/$$   # staged out of plugins/ until the yes: an interrupted add sources nothing
    command rm -rf -- $dir; command mkdir -p $root $root.new
    local err; err=$(git clone --quiet --no-recurse-submodules -- $url $dir 2>&1 >/dev/null) || {
      command rm -rf -- $dir; _shkit_url $err; print -ru2 -- $REPLY
      _shkit_url $url; print -ru2 -- "shkit: can't clone $REPLY"; return 1
    }
    _shkit_check $dir HEAD || { command rm -rf -- $dir; return 1 }
    name=$REPLY
    [[ -e $root/$name ]] && { command rm -rf -- $dir; print -u2 "shkit: plugin '$name' already there (shkit plugin update $name)"; return 1 }
    _shkit_ask $yes "Source these files in every shell?" || { command rm -rf -- $dir; print cancelled; return 1 }
    command mv -- $dir $root/$name || return
    _prompt_load_blocks; _shkit_reset
    print -r -- "added; a theme: shkit set theme $name/<theme>" ;;
  (update)
    local -a names=(${1:-$root/*(N/:t)})
    for name in $names; do
      [[ $name =~ $re && -d $root/$name/.git ]] || { print -u2 "shkit: no plugin '$name'"; continue }
      dir=$root/$name
      git -C $dir fetch --quiet 2>/dev/null || { print -u2 "shkit: $name: fetch failed (shkit plugin list: its URL)"; continue }
      git -C $dir rev-parse -q --verify '@{u}' >/dev/null || { print -u2 "shkit: $name: no upstream branch"; continue }
      if [[ $(git -C $dir rev-parse HEAD) == $(git -C $dir rev-parse '@{u}') ]]; then print -r -- "$name: up to date"; continue; fi
      git -C $dir merge-base --is-ancestor HEAD '@{u}' ||
        { print -u2 "shkit: $name: its history was rewritten upstream, not applied (remove and add it again)"; continue }
      git -C $dir --no-pager log --format='  %h %cs %s' 'HEAD..@{u}'
      git -C $dir --no-pager diff --stat HEAD '@{u}'
      _shkit_check $dir '@{u}' || continue   # the new version, before it is applied
      [[ $REPLY == $name ]] || { print -u2 "shkit: $name: renamed to '$REPLY' upstream, not applied"; continue }
      _shkit_ask $yes "Apply?" || continue
      git -C $dir merge --quiet --ff-only '@{u}' || continue
    done
    _prompt_load_blocks; _shkit_reset ;;
  (remove)
    name=$1
    [[ $name =~ $re && -d $root/$name ]] || { print -u2 "shkit: no plugin '$name'"; return 1 }
    command rm -rf -- $root/$name
    _prompt_load_blocks; _shkit_reset
    print -r -- "removed; its blocks stay defined in the shells already open (exec zsh)"
    [[ $SHKIT_THEME == $name/* ]] && print -r -- "SHKIT_THEME is still $SHKIT_THEME: shkit unset theme" ;;
  (new)
    name=$1 dir=${${2:-$PWD/$1}:a}
    [[ $name =~ '^[a-z0-9][a-z0-9-]*$' ]] || { print -u2 "usage: shkit plugin new NAME [DIR] (NAME: a-z, 0-9, -)"; return 1 }
    [[ -e $dir ]] && { print -u2 "shkit: $dir already exists"; return 1 }
    (( $+commands[jq] )) || { print -u2 "shkit: jq is needed to write plugin.json"; return 1 }
    command mkdir -p $dir || return
    local author=$(git config user.name)
    jq -n --arg n $name --arg a "$author" '{
        "$schema": "https://github.com/fmatsos/shellkit/zsh/plugin/schema.json",
        name: $n, version: "0.1.0", description: "\($n): blocks and themes for the zsh prompt"
      } + (if $a != "" then {author: {name: $a}} else {} end)' >| $dir/plugin.json || return
    git init -q -b main $dir
    print -rl -- "${dir/#$HOME/~}: plugin '$name' (plugin.json; example: $_shkit_schema/example)" \
      "next, in it:  shkit plugin new-block NAME 'what it shows'   (and/or new-theme)" \
      "              shkit plugin check; git commit; git push" \
      "then:         shkit plugin add <its URL>   (a local path works too, once committed)" ;;
  (new-block|new-theme)
    local kind=${${sub#new-}}s top=${$(git rev-parse --show-toplevel 2>/dev/null):-$PWD}
    name=$1
    [[ -r $top/plugin.json ]] || { print -u2 "shkit: not in a plugin repository (no plugin.json; shkit plugin new NAME)"; return 1 }
    if [[ $kind == blocks ]]; then [[ $name =~ '^[a-z0-9_]+$' ]]; else [[ $name =~ '^[a-z0-9][a-z0-9_-]*$' ]]; fi ||
      { print -u2 "usage: shkit plugin $sub NAME [DESCRIPTION] (block: a-z 0-9 _; theme: a-z 0-9 _ -)"; return 1 }
    f=$top/$kind/$name.zsh
    [[ -e $f ]] && { print -u2 "shkit: ${f#$top/} already exists"; return 1 }
    local desc=${2:-$name}
    command mkdir -p $top/$kind
    if [[ $kind == blocks ]]; then
      print -rl -- "# {$name}: $desc" \
        "# Local and fast (< a few ms), or a background job: see the prompt-plugin skill." \
        "function _prompt_seg_$name {" \
        "  local text=$name   # what to show; nothing appended = the block and its separator hidden" \
        "  _prompt_esc \$text   # every dynamic text is escaped" \
        "  segs+=\"\${_c_accent}\${REPLY}\${_c_reset}\"   # colors: \$_c_<role>, icons: \$_i_<name>" \
        "}" >| $f
    else
      print -rl -- "# $desc — SHKIT_* assignments only (shkit list: every name)." \
        "SHKIT_COLOR_ACCENT='36'" >| $f
    fi
    jq --arg k $kind --arg n $name --arg d $desc '.[$k] = ((.[$k] // []) + [{name: $n, description: $d}])' \
      $top/plugin.json >| $top/plugin.json.new && command mv -f $top/plugin.json.new $top/plugin.json
    print -r -- "${f#$top/}: written, declared in plugin.json"
    _shkit_check $top '' >/dev/null ;;
  (check)
    dir=${1:-${$(git rev-parse --show-toplevel 2>/dev/null):-$PWD}}
    _shkit_check ${dir:a} '' && print "valid" ;;
  (list)
    for dir in $root/*(N/); do
      _shkit_url "$(git -C $dir remote get-url origin 2>/dev/null)"
      print -r -- "${dir:t} $(jq -r '"\(.version) — \(.description)"' $dir/plugin.json 2>/dev/null)"
      print -r -- "  $REPLY @ $(git -C $dir log -1 --format='%h %cs' 2>/dev/null)"
      local -a b=($dir/blocks/*.zsh(N:t:r)) th=($dir/themes/*.zsh(N:t:r))
      print -r -- "  blocks: ${(j: :)b:-none} · themes: ${(j: :)th:-none}"
    done ;;
  (*)
    print -u2 "usage: shkit plugin add [-y] URL | update [-y] [NAME] | remove NAME | list | new NAME [DIR] | new-block NAME [DESC] | new-theme NAME [DESC] | check [DIR]"
    return 1 ;;
  esac
}

# shellkit to its latest release: origin's `release` branch, which release.yml moves
# to a vX.Y.Z tag only once the CI passed on it (a tag whose checks fail never gets
# there, nor a pre-release). Plain git, no API: works for a private repository.
# Fast-forward only: a clone with commits of its own is left to git pull.
typeset -g _shkit_root=${${(%):-%x}:A:h:h}
function _shkit_update { # [-y] -> REPLY: the release it moved to, '' if none
  local r=$_shkit_root yes=0 cur tag
  REPLY=
  [[ $1 == -y ]] && yes=1
  git -C $r symbolic-ref -q HEAD >/dev/null || { print -u2 "shkit: $r is not on a branch"; return 1 }
  # no `+` in the refspec, no --force: a rewritten release branch or a moved tag is refused
  GIT_TERMINAL_PROMPT=0 _prompt_timeout 60 git -C $r fetch --quiet --tags origin \
    refs/heads/release:refs/remotes/origin/release 2>/dev/null ||
    { print -u2 "shkit: no release yet, or can't fetch shellkit's origin"; return 1 }
  tag=$(git -C $r describe --tags --always origin/release)
  cur=$(git -C $r describe --tags --always)
  git -C $r merge-base --is-ancestor origin/release HEAD && { print -r -- "shellkit $cur: up to date (latest release: $tag)"; return 0 }
  git -C $r merge-base --is-ancestor HEAD origin/release ||
    { print -u2 "shkit: $r has commits $tag doesn't: update it with git"; return 1 }
  print -r -- "shellkit $cur -> $tag"
  git -C $r --no-pager log --oneline --no-decorate HEAD..origin/release
  git -C $r --no-pager diff --stat HEAD origin/release | tail -1
  _shkit_ask $yes "Update shellkit to $tag?" || return 1
  git -C $r merge --quiet --ff-only origin/release || return
  REPLY=$tag
  print -r -- "shellkit $tag: run exec zsh in each open shell"
}

# At startup, at most once per SHKIT_UPDATE_TTL (s): a detached job runs the same
# update, only on the default branch without local changes (a branch of your own,
# or work in progress, is never moved), and the next shell says so, once.
# Off: SHKIT_AUTO_UPDATE=false in settings.sh.
function _shkit_job_update { # FILE
  local r=$_shkit_root main
  _prompt_write $1 ""   # stamp first: offline = retry after the TTL, not at each shell
  main=$(git -C $r symbolic-ref -q --short refs/remotes/origin/HEAD); main=${${main#origin/}:-main}
  [[ $(git -C $r symbolic-ref -q --short HEAD) == $main && -z $(git -C $r status --porcelain -uno 2>/dev/null) ]] || return 0
  local old=$(git -C $r describe --tags --always 2>/dev/null)
  GIT_SSH_COMMAND='ssh -o BatchMode=yes -o ConnectTimeout=5' _shkit_update -y >/dev/null 2>&1 && [[ -n $REPLY ]] &&
    print -r -- "shellkit updated: $old -> $REPLY (exec zsh in the shells already open)" >| $1.news
}

function _shkit_autoupdate {
  local file _ts _data
  _prompt_key shkit-update; file=$REPLY
  [[ -r $file.news ]] && { print -ru2 -- "$(<$file.news)"; command rm -f -- $file.news }
  [[ ${SHKIT_AUTO_UPDATE:-true} == true ]] || return 0
  _prompt_read $file
  (( EPOCHSECONDS - _ts >= ${SHKIT_UPDATE_TTL:-86400} )) && _prompt_spawn $file _shkit_job_update $file
}

# One line per check: ok, warn (works, with less), FAIL (broken: exit 1), -- (not in use).
# Local only, but for the logins of glab / gh, whose status is shown, never their output.
function _shkit_say { print -r -- "${(r:5:)1}$2"; [[ $1 == FAIL ]] && bad=1; }   # bad: _shkit_doctor's
function _shkit_doctor {
  local r=$_shkit_root d=${SHELL_LOCAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/shkit} v f c _ts _data
  local -a m fonts
  integer bad=0
  autoload -Uz is-at-least
  if is-at-least 5.8; then _shkit_say ok "zsh $ZSH_VERSION"; else _shkit_say FAIL "zsh $ZSH_VERSION: 5.8+ needed"; fi
  [[ $(git --version 2>/dev/null) =~ '[0-9]+\.[0-9]+(\.[0-9]+)?' ]] && v=$MATCH || v=
  if [[ -n $v ]] && is-at-least 2.31 $v; then _shkit_say ok "git $v"; else _shkit_say FAIL "git ${v:-not found}: 2.31+ needed"; fi
  v=${LC_ALL:-${LC_CTYPE:-$LANG}}   # the codeset in effect: macOS' plain UTF-8 too, not a locale set but not installed
  zmodload zsh/langinfo 2>/dev/null && c=$langinfo[CODESET] || c=${v##*.}
  if [[ $c == (UTF-8|utf-8|UTF8|utf8) ]]; then _shkit_say ok "locale ${v:-C} ($c)"; else _shkit_say FAIL "locale '${v:-none}': not UTF-8, icons can't show"; fi
  if (( $+commands[fc-list] )); then fonts=(${(f)"$(fc-list 2>/dev/null | grep -i 'nerd')"})
  else fonts=({~/.local/share/fonts,~/Library/Fonts,/Library/Fonts,/usr/share/fonts}/**/*[Nn]erd*(N.))
  fi
  if (( $#fonts )); then _shkit_say ok "a Nerd Font is installed (the terminal must use it, or fall back to it)"
  else _shkit_say warn "no Nerd Font found: some icons show as boxes (docs/installation.md)"; fi
  if (( $+commands[bash] )); then
    v=$(bash -c 'echo ${BASH_VERSINFO[0]}.${BASH_VERSINFO[1]}' 2>/dev/null)
    if is-at-least 5.1 $v; then _shkit_say ok "bash $v (fallback)"; else _shkit_say warn "bash $v: the bash config needs 5.1+"; fi
  fi

  if (( $+commands[jq] )); then _shkit_say ok jq; else _shkit_say warn "jq not installed: no {mr} / {review} on GitLab, no plugins"; fi
  for c in glab gh; do
    if (( ! $+commands[$c] )); then _shkit_say -- "$c not installed (${${c:#gh}:+GitLab}${${c:#glab}:+GitHub} MR / PR)"
    else
      v=$(_prompt_timeout 10 $c auth status 2>&1)   # read, never printed (it may hold a token)
      if (( ! $? )); then _shkit_say ok "$c, logged in"
      elif [[ $v == *'Logged in to'* ]]; then _shkit_say warn "$c: a configured host rejects its login ($c auth status)"
      else _shkit_say warn "$c: not logged in ($c auth login), no MR / PR"; fi
    fi
  done
  if (( ! $+commands[docker] )); then _shkit_say -- "docker not installed"
  elif _prompt_timeout 5 docker ps -q >/dev/null 2>&1; then _shkit_say ok docker
  else _shkit_say warn "docker: the daemon doesn't answer, no {docker} / {stack}"; fi
  if [[ $SHKIT_NOTIFY != true ]] || (( SHKIT_NOTIFY_AFTER <= 0 )); then _shkit_say -- "notifications off (SHKIT_NOTIFY)"
  elif [[ -n $SSH_CONNECTION ]]; then _shkit_say ok "notifications after ${SHKIT_NOTIFY_AFTER}s: the bell (SSH)"
  elif (( $+commands[notify-send] || $+commands[osascript] )); then _shkit_say ok "notifications after ${SHKIT_NOTIFY_AFTER}s"
  else _shkit_say warn "no notify-send: a long command only rings the bell"; fi

  [[ -d ${d%/*}/shell ]] && _shkit_say warn "${${d%/*}/#$HOME/~}/shell: not migrated (shell/install-local.sh)"
  if [[ ! -d $d ]]; then _shkit_say -- "${d/#$HOME/~}: not created yet (shkit set creates it)"
  else
    zstat -A m -o +mode $d
    if (( ! (8#${m[1]: -3} & 8#077) )); then _shkit_say ok "${d/#$HOME/~} (700)"; else _shkit_say warn "${d/#$HOME/~}: chmod 700 (is ${m[1]: -3})"; fi
    f=$d/secrets.sh
    if [[ -e $f ]]; then
      zstat -A m -o +mode $f
      if (( ! (8#${m[1]: -3} & 8#077) )); then _shkit_say ok "secrets.sh (600)"; else _shkit_say FAIL "secrets.sh: readable by others, chmod 600 (is ${m[1]: -3})"; fi
    fi
  fi
  local -a old=()
  for f in $d/{settings.sh,theme.zsh}(N) $d/projects/*.zsh(N); do   # 1.0's names, not bash's or zsh's own
    v=${"$(<$f)"//${~_prompt_foreign}=/}
    [[ $v =~ '(^|[[:space:]#])PROMPT_[A-Z0-9_]+=' ]] && old+=$f
  done
  m=($old)
  (( $#m )) && _shkit_say warn "shellkit 1.0 names (PROMPT_*) in ${(j:, :)${m:t}}: still read; shell/install-local.sh renames them"
  f=${ZDOTDIR:-$HOME}/.zshrc
  if [[ ${f:A} == $r/zsh/zshrc ]]; then :
  elif [[ -n $SHKIT_TRY ]]; then _shkit_say -- "trying shellkit (zsh/try.sh): nothing is kept"
  elif (( $+functions[_zshrc_jump] )); then _shkit_say warn "${f/#$HOME/~} doesn't link to $r/zsh/zshrc (zsh/install.sh)"
  else _shkit_say -- "prompt only: ${f/#$HOME/~} is your own and sources prompt.zsh"; fi
  [[ -w $_prompt_cache ]] || _shkit_say FAIL "$_prompt_cache: not writable, the prompt can't cache"

  v=$(git -C $r describe --tags --always 2>/dev/null)
  c=$(git -C $r symbolic-ref -q --short HEAD)
  if [[ -z $c ]]; then _shkit_say warn "shellkit $v: not on a branch, no update"
  elif [[ -n $(git -C $r status --porcelain -uno 2>/dev/null) ]]; then _shkit_say warn "shellkit $v: local changes, no auto-update"
  else _shkit_say ok "shellkit $v ($c)"; fi
  if git -C $r rev-parse -q --verify origin/release >/dev/null && ! git -C $r merge-base --is-ancestor origin/release HEAD; then
    _shkit_say warn "release $(git -C $r describe --tags --always origin/release) is out: shkit update"
  fi
  _prompt_key shkit-update; _prompt_read $REPLY
  if [[ ${SHKIT_AUTO_UPDATE:-true} != true ]]; then _shkit_say -- "auto-update off (SHKIT_AUTO_UPDATE)"
  elif (( _ts )); then strftime -s v '%F %H:%M' $_ts; _shkit_say ok "auto-update, last check $v"
  else _shkit_say ok "auto-update, not checked yet"; fi

  if [[ -n $SHKIT_THEME && -z ${(M)${(f)"$(_shkit_themes)"}:#$SHKIT_THEME} ]]; then _shkit_say FAIL "theme $SHKIT_THEME: not installed"; fi
  for f in $d/plugins/*(N/); do
    if v=$(_shkit_check $f HEAD 2>&1); then _shkit_say ok "plugin ${f:t}"
    else _shkit_say FAIL "plugin ${f:t}: ${${(f)v}[1]#shkit: }"; fi
  done
  return bad
}

typeset -g _shkit_schema=${${(%):-%x}:A:h}/plugin   # schema.json, validate.jq

function _shkit_cat { # DIR REV FILE -> the file at REV ('' = the working tree)
  if [[ -n $2 ]]; then git -C $1 show "$2:$3" 2>/dev/null
  else [[ -r $1/$3 ]] && print -r -- "$(<$1/$3)"
  fi
}

# DIR REV -> REPLY: the plugin's name, once REV's plugin.json follows schema.json
# and blocks/, themes/ hold exactly the declared files. Prints what will be sourced.
# REV '' = the working tree (plugin check, while writing one).
function _shkit_check {
  local dir=$1 rev=$2 m e f n
  (( $+commands[jq] )) || { print -u2 "shkit: jq is needed to read plugin.json"; return 1 }
  m=$(_shkit_cat $dir "$rev" plugin.json) ||
    { print -u2 "shkit: no plugin.json at the root (format: $_shkit_schema/schema.json)"; return 1 }
  e=$(jq -r --slurpfile schema $_shkit_schema/schema.json -f $_shkit_schema/validate.jq <<<$m 2>&1) ||
    e="plugin.json: not valid JSON"
  [[ -z $e ]] || { print -rlu2 -- "shkit: "${^${(f)e}}; return 1 }
  local -a want=(${(f)"$(jq -r '(.blocks // [])[] | "blocks/\(.name).zsh"' <<<$m)"}
                 ${(f)"$(jq -r '(.themes // [])[] | "themes/\(.name).zsh"' <<<$m)"})
  local -a have
  if [[ -n $rev ]]; then have=(${(f)"$(git -C $dir ls-tree -r --name-only $rev -- blocks themes)"})
  else have=($dir/blocks/**/*(ND.) $dir/themes/**/*(ND.)); have=(${have#$dir/})
  fi
  e=
  local -aU once=($want)
  (( $#want == $#once )) || e+=$'\n'"a block or theme is declared twice"
  for f in ${want:|have}; do e+=$'\n'"$f: declared, not in the repository"; done
  for f in ${have:|want}; do e+=$'\n'"$f: not declared in plugin.json"; done
  for f in ${(M)want:#blocks/*}; do
    [[ $(_shkit_cat $dir "$rev" $f) == *"_prompt_seg_${${f:t}%.zsh}"* ]] ||
      e+=$'\n'"$f: no function _prompt_seg_${${f:t}%.zsh}"
  done
  [[ -z $e ]] || { print -rlu2 -- "shkit: "${^${(f)e#$'\n'}}; return 1 }
  n=$(jq -r .name <<<$m)
  _shkit_url "$(git -C $dir remote get-url origin 2>/dev/null)"
  print -r -- "$n $(jq -r .version <<<$m): $(jq -r .description <<<$m)"
  print -r -- "  from ${REPLY:-$dir} @ $(git -C $dir log -1 --format='%h %cs %s' ${rev:-HEAD} 2>/dev/null)"
  print -rl -- "  sourced: "$^want
  for f in ${(f)"$(jq -r '(.requires // [])[]' <<<$m)"}; do
    (( $+commands[$f] )) || print -r -- "  note: needs $f, not installed"
  done
  REPLY=$n
}

function _shkit_complete {
  local -a names=(${(L)${(k)parameters[(I)SHKIT_*]}#shkit_})
  if (( CURRENT == 2 )); then compadd show list set unset project edit plugin update doctor
  elif [[ $words[2] == set && $words[CURRENT-1] == theme ]]; then compadd -- ${(f)"$(_shkit_themes)"}
  elif [[ $words[2] == (set|unset) ]]; then compadd -- -p ${names:#project_dir}
  elif [[ $words[2] == plugin && CURRENT -eq 3 ]]; then compadd add update remove list new new-block new-theme check
  elif [[ $words[2] == plugin && $words[3] == (update|remove) ]]; then
    compadd -- ${SHELL_LOCAL_DIR:-${XDG_CONFIG_HOME:-$HOME/.config}/shkit}/plugins/*(N/:t)
  elif [[ $words[2] == project ]]; then _directories
  elif [[ $words[2] == edit ]]; then compadd -- -p
  fi
}
(( $+functions[compdef] )) && compdef _shkit_complete shkit
_shkit_autoupdate
