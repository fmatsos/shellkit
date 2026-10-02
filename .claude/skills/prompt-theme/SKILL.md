---
name: prompt-theme
description: Develop or tweak the zsh prompt (zsh/prompt.zsh) — add or change a segment, a color role, an icon, a background job (git fetch, MR/PR, docker…), or the async redraw; theme variables in ~/.config/shkit/theme.zsh, per-project settings (projects/), plugins (git repositories of blocks and themes), and the shkit command. Use for any change to what the prompt shows or how it looks.
---

# The zsh prompt and its theme

`zsh/prompt.zsh` is the only full prompt. Bash keeps a minimal `__git_ps1`
prompt in `bash/bashrc` on purpose: **don't port prompt features to bash**.
The Claude Code statusline (`~/.claude/statusline-command.sh`) is a separate
subject: never change it from here, with one exception — it writes the quota
file `{quota}` reads (`~/.cache/claude-quota`: `5h% reset 7d% reset`, epochs).
The prompt reuses its color roles and its quota gradient.

## Anatomy

- **Layers** (`_prompt_compose`, at load, on a project switch, after each `shkit`),
  each over the one before; every `SHKIT_*` is rebuilt from them:
  1. defaults: `_prompt_defaults` in `prompt.zsh`, then the blocks' own;
  2. `SHKIT_THEME`'s file, `plugins/<plugin>/themes/<theme>.zsh`;
  3. `settings.sh` and the environment, as they were when `prompt.zsh` loaded;
  4. `~/.config/shkit/theme.zsh` (read by `prompt.zsh`, not by `zshrc`);
  5. the project file.

  Files are sourced inside a function: plain assignments only (`typeset` alone makes a local).
  A `SHKIT_*` typed at the shell lasts until the next compose.
- **Theme** variables:
  - `SHKIT_FORMAT` (info line) and `SHKIT_RIGHT_FORMAT` (right end of the info
    line, padded to `$COLUMNS` by `_prompt_render`, dropped when it can't fit, again on
    `TRAPWINCH`; the input line holds only the `$`): see **Layout** below;
  - `SHKIT_SEPARATOR`: between the parts of one block (`{git}`: branch · status · rebase);
  - `SHKIT_COLOR_<ROLE>`: an SGR code, compiled at load into `$_c_<role>`;
  - `SHKIT_ICON_<NAME>`: compiled into `$_i_<name>`, %-escaped; the ones followed by
    a space get it only when non-empty;
  - `SHKIT_SPINNER` (tab title).
- **Behaviour** (in `~/.config/shkit/settings.sh`): `SHKIT_SHOW_MR`, `SHKIT_QUOTA_RESET_AT`, `SHKIT_AUTO_FETCH`,
  `SHKIT_TITLE_SPINNER`, `SHKIT_*_TTL`, `SHKIT_DIFF_MAX_FILES`.
- **Segment** (= a `{name}` block): `_prompt_seg_<name>` appends its string(s) to
  `segs` (several are joined with `SHKIT_SEPARATOR`), and appends to `pending` the
  cache files whose refresh is in flight. `{mr}` reads `_git` (common dir, branch,
  top), which `{git}` sets: it shows nothing without `{git}` earlier on the line.
- **Format engine**: `_prompt_compile SIDE FORMAT` parses a format into
  `_prompt_fmt_<side>_n` (block names) and `_t` (texts, escaped, muted), again only
  when the string changes. `_prompt_line SIDE` renders it; `_prompt_render` calls it
  for `l` (PROMPT line 1) and `r` (`_prompt_right`, appended to line 1).

- **Background job**: `_prompt_job_<name>` computes, then `_prompt_write FILE DATA`
  (atomic, `<epoch>\n<TSV>`). The segment reads it with `_prompt_read` (sets `_ts`,
  `_data`), and when `SPAWN` is set and the TTL is expired it calls
  `_prompt_spawn FILE _prompt_job_<name> …` (detached, one lock dir per file).
- **Async redraw**: precmd renders with `SPAWN=1`. If anything is pending, a
  `_prompt_watch` process waits for the lock dirs to go away while spinning the tab
  title. `zle -F` then runs `_prompt_async_done`, which re-renders and calls
  `zle reset-prompt`.

## Layout (`SHKIT_FORMAT`, `SHKIT_RIGHT_FORMAT`)

Defaults: `'{host} · {dir} · {git} · {ticket} · {mr}  {review} · {stack} · {docker} · {duration} · {status}'`
and `'{agents} · {quota}'`. Blocks: `host`, `dir`, `git`, `ticket`, `mr`, `review`, `stack`,
`docker`, `duration`, `status`, `agents`, `quota`, plus local ones
(`~/.config/shkit/prompt.d/`, below). To change the bar, edit the
string in `~/.config/shkit/theme.zsh` (a block can move from one side to the other).

- `{name}`: a block; an empty or unknown one shows nothing.
- Text between two blocks is a **separator**: shown only when a block shows on each
  side; when blocks in between are empty, the text right before the next shown block
  is used.
- Text before the first block and after the last one always shows (prefix/suffix).
- All literal text is muted and printed verbatim (`%`, `$(…)` are not interpreted).
- Not supported: decorating one block (e.g. `[{mr}]`: the `]` is a separator, lost
  when `{mr}` is followed by an empty block), per-text colors, a literal `{name}`.
  Add them to `_prompt_compile` / `_prompt_line` when a use needs them.

## Adding a segment

1. Write `_prompt_seg_<name>`: colors from `$_c_<role>` only, glyphs from
   `$_i_<name>` only (add `SHKIT_ICON_<NAME>` to the defaults and to the right
   compile loop). Every dynamic text goes through `_prompt_esc` before it enters `segs`.
2. Local and fast → compute inline. Anything networked or > a few ms → a job plus
   the cache, never inline.
3. Add its `{name}` to the `SHKIT_FORMAT` or `SHKIT_RIGHT_FORMAT` default and to
   the block list above, and list the new variables in `README.md` and the
   commented template of `~/.config/shkit/theme.zsh`.
4. Add a check to `zsh/prompt.check.zsh`, then run the `config-commit` checks.

## Per project (`~/.config/shkit/projects/<name>.zsh`) and `shkit`

- A project file starts with `SHKIT_PROJECT_DIR='~/code/shop'`: read (not run) at load
  by `_prompt_projects_load`. In that directory and below (worktrees inside
  included; the deepest one wins), `_prompt_project_switch` (start of every render,
  a string compare unless the project changed) composes the layers with it; leaving
  composes them without it.
- Any `SHKIT_*` can be overridden per project (formats, colors, icons, `SHOW_MR`, TTLs).
  `SHKIT_THEME` too. Blocks stay global (`prompt.d/`, plugins): a project's format picks them.
- Keyed by path, not by repo: no git call before rendering, works outside git.
  Not a `.prompt` file inside the project: a cloned repo would run code on `cd`.
- `shkit` (`zsh/shkit.zsh`) edits these files for the user: `set [-p] NAME
  VALUE…`, `unset [-p] NAME`, `project [DIR]`, `edit [-p]`, `show`, `list` (completion
  included). Values are written `(q+)`-quoted, then every layer is read again
  (`_shkit_reset`): applied at once, `unset` included. Point the user to it
  rather than to hand edits.

## Plugins (`~/.config/shkit/plugins/<name>/`, `shkit plugin`)

A plugin is a git repository of blocks and themes, cloned by `shkit plugin add
URL`. Its layout is fixed, like a Claude Code plugin's:

```
plugin.json          # manifest: follows zsh/plugin/schema.json
blocks/<name>.zsh    # _prompt_seg_<name>, same contract as a local block (below)
themes/<name>.zsh    # SHKIT_* assignments; picked with: shkit set theme <plugin>/<name>
```

- `plugin.json`: `name` (the install directory and theme prefix, never renamed),
  `version` (semver), `description`, and `blocks` and/or `themes` (`{name, description}`
  each). Optional: `author`, `license`, `homepage`, `repository`, `keywords`, `requires`
  (commands the blocks run: a missing one is noted). Any other key is refused.
- `_shkit_check DIR REV` enforces it on `add` and on `update` (the incoming
  version, before it is applied):
  - the manifest against the schema, with `zsh/plugin/validate.jq` (jq only; a plugin's
    CI can run it too);
  - `blocks/` and `themes/` hold exactly the declared files;
  - each block file defines its `_prompt_seg_<name>`.
- `validate.jq` reads the schema itself and knows only its keywords (type, required,
  anyOf of required, properties, additionalProperties, items, minItems, minLength,
  pattern). A new keyword in `schema.json` needs its support there, or it is ignored.
- `zsh/plugin/example/` is a complete sample; the self-check validates it.
- Writing one: the `prompt-plugin` skill, and `shkit plugin new` / `new-block` /
  `new-theme` / `check` (`check` = `_shkit_check DIR ''`, the working tree).

- Blocks load before `prompt.d/` (a local block of the same name wins), themes are layer 2.
- It is code in every shell, so:
  - nothing is fetched unless asked, and the clone's HEAD is the pin;
  - `add` lists the files that will be sourced and asks;
  - `update` fetches, shows `log` + `diff --stat`, asks, then `merge --ff-only`, and
    refuses a rewritten history;
  - `-y` skips the question (scripts, the check).
- Names are checked: a plugin is `[A-Za-z0-9_][A-Za-z0-9._-]*`, `SHKIT_THEME` is
  `<plugin>/<theme>`, never a path. The URL goes after `git clone --`.
- Rule #1: a URL's `user:token@` is never printed (`_shkit_url`); prefer ssh URLs
  or a credential helper.
- `remove`: the blocks' functions stay in the shells already open until `exec zsh`.

## A local block (`~/.config/shkit/prompt.d/<name>.zsh`)

For a block the repo doesn't need (one machine, one project), without touching
`prompt.zsh`. Files are sourced after the built-in segments, then the theme is
compiled, so a file can set its own color/icon defaults:

```zsh
# ~/.config/shkit/prompt.d/php.zsh -> {php}
: ${SHKIT_COLOR_PHP:='38;5;104'} ${SHKIT_ICON_PHP=$'\ue73d'}
function _prompt_seg_php {
  [[ -f composer.json ]] || return 0             # nothing = block hidden, its separator too
  local v='?'; [[ -r .php-version ]] && v=$(<.php-version)
  _prompt_esc $v
  segs+="${_c_php}${_i_php} ${REPLY}${_c_reset}"
}
```

- Contract: append to `segs` (several strings = joined with `SHKIT_SEPARATOR`);
  `$_c_<role>` / `$_i_<name>` exist for every `SHKIT_COLOR_*` / `SHKIT_ICON_*`
  (an icon gets no trailing space); `_prompt_esc` on every dynamic text; the name
  matches `[a-z0-9_]+` (a dot: kept for the built-ins' variants, `{dir.short}`).
- Same name as a built-in (`_prompt_seg_docker`) = overrides it.
- The file is sourced inside a function: a global it keeps needs `typeset -g`
  (`typeset -A x` alone would be a local, gone once loaded). It is sourced again after
  each `shkit plugin` change, so keep it idempotent.
- Slow or networked: the cache API, as the built-in jobs — `_prompt_key NAME`,
  `_prompt_read`, and when `SPAWN` is set and the TTL expired, `_prompt_spawn FILE
  _prompt_job_<name> …` + `pending+=$FILE`; the job ends with `_prompt_write`.
- The 50 ms budget and the injection rule apply as for a built-in: time it with
  `repeat 20 _prompt_render`. A block in the repo instead: **Adding a segment**.

## Rules that are there for a reason

- **Injection**: `NO_PROMPT_SUBST` stays; a branch named `$(…)` or `%F{red}` must
  print verbatim (checked). Non-printing escapes go in `%{ … %}`.
- **Budget**: the synchronous path < 50 ms on a large repository (~35k files). Measure it in
  a large repo: `zsh -c 'source zsh/prompt.zsh; time (repeat 20 _prompt_render)'` (total / 20; ~22 ms on a 35k-file repository).
  Hence `git status -uno` (18 ms vs 114 ms) and no diff stat above
  `SHKIT_DIFF_MAX_FILES`.
- **Jobs**: stamp the cache before a call that can fail (no retry storm); put
  `_prompt_timeout SECS` on every network call (GNU `timeout`, else `gtimeout`, else
  perl on macOS), use `GIT_TERMINAL_PROMPT=0` and ssh `BatchMode=yes`.
  A lock older than 2 min is forgotten (`_prompt_locked`, in `_prompt_spawn`).
- **macOS**: no `/proc` (`{agents}` then checks the pid is alive only, `_prompt_proc`),
  no GNU `stat`/`date` (use `zstat`, `$EPOCHREALTIME`); paths compared as real paths
  (`:A`), since `/tmp` and `/var` are symlinks there.
- **noclobber** is on: write with `>|`. Use `command mkdir/mv/rm`, because the aliases
  from `shell/aliases.sh` (`mkdir -pv`…) print messages.
- **zsh gotchas met here**:
  - save `$?` first thing in precmd;
  - close an fd with `local fd=$1; exec {fd}<&-`;
  - join with a variable: `${(pj:$sep:)segs}`;
  - use `${X=default}`, not `:=`, for anything that may be set empty;
  - use an `integer` variable, not `int()`;
  - assign an array whose name is computed with `set -A name_$x …` (`typeset -ga name_$x=(…)` is a parse error);
  - `EXTENDED_GLOB` is needed only in the check.
- **Title**: OSC 0 is written only while `state.$$` says the shell is idle (`0`).
  Claude Code also sets the title, so don't animate while a command runs.

## Testing

- `zsh zsh/prompt.check.zsh`: runs in a temp `HOME` and `XDG_RUNTIME_DIR` with
  noclobber, and no network is needed.
- Stub external tools with an executable in a `PATH` dir: `_prompt_timeout` runs
  binaries, so it ignores shell functions. The macOS fallbacks are checked on Linux
  (`unhash timeout`, `_prompt_proc=<none>`).
- Aliases that the prompt must survive are defined around the `source`, then
  unaliased.
- Real async redraw: open a new tab (or run `exec zsh`) and watch ↻ turn into the
  data without pressing Enter. Links (OSC 8) and the title were validated in
  Ptyxis and the PhpStorm terminal.
