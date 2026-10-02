# Writing a block

A block is a zsh function, `_prompt_seg_<name>`, shown wherever a format has
`{name}`.

- [Where blocks live](#where-blocks-live)
- [A first block](#a-first-block)
- [The contract](#the-contract)
- [Colors and icons](#colors-and-icons)
- [Slow data: background jobs](#slow-data-background-jobs)
- [Testing](#testing)

## Where blocks live

| Where | For |
|-------|-----|
| `~/.config/shkit/prompt.d/<name>.zsh` | this machine only |
| `blocks/<name>.zsh` in a [plugin](plugins.md) | to share |
| `zsh/prompt.zsh` | built-ins, part of shellkit itself |

Blocks load in that order: plugins, then `prompt.d/`. A later block with the same
name wins, even over a built-in.

## A first block

```zsh
# ~/.config/shkit/prompt.d/php.zsh -> {php}
: ${SHKIT_COLOR_PHP:='38;5;104'} ${SHKIT_ICON_PHP=$''}   # own defaults, overridable

function _prompt_seg_php {
  [[ -f composer.json ]] || return 0              # nothing appended = block hidden
  local v='?'
  [[ -r .php-version ]] && v=$(<.php-version)
  _prompt_esc $v                                  # every dynamic text
  segs+="${_c_php}${_i_php} ${REPLY}${_c_reset}"
}
```

```zsh
exec zsh                              # load it
shkit set format '{dir} · {git} · {php}'
```

## The contract

1. **Append to `segs`, or append nothing.** Each element of `segs` is one part of
   the block, joined with `SHKIT_SEPARATOR`. Nothing appended hides the block,
   and the separators around it too.
2. **Escape every dynamic text** with `_prompt_esc TEXT`, which sets `REPLY`.
   Branch names, file contents and API answers may contain `%` or `$(…)`. Never
   use `eval`, and never turn `PROMPT_SUBST` on.
3. **Stay fast.** The function runs at every prompt, so a few milliseconds at most.
   No network, nothing that can hang. Slow data goes through a
   [background job](#slow-data-background-jobs).
4. **Sourced inside a function, possibly many times.** The file is sourced again
   whenever plugins change. So:
   - globals need `typeset -g` (a bare `typeset` makes a local);
   - only defaults (`: ${X:=…}`), functions and nothing else at the top level, with
     no side effects.
5. **Portable**: it must run the same on Linux and macOS. No GNU-only flags
   (`stat -c`, `date +%N`, `sed -i`, `timeout`), no `/proc` without a fallback.
   Prefer zsh builtins (`zstat`, `$EPOCHREALTIME`, `${file:A}`).
6. **No secrets in the file.** Read a variable (`$GITLAB_TOKEN`) that the user sets
   in `secrets.sh`.

Block names are lowercase letters, digits and `_`. A dot is kept for the built-ins'
variants (`{dir.short}`, `{git.untracked}`).

## Colors and icons

Never write color codes or glyphs directly in the function. Use the variables built
from the settings:

| In the block | Comes from |
|--------------|-----------|
| `$_c_<role>` | `SHKIT_COLOR_<ROLE>`, for example `$_c_accent`, `$_c_mute` or your own `$_c_php` |
| `$_c_reset` | ends a color |
| `$_i_<name>` | `SHKIT_ICON_<NAME>`, for example `$_i_branch` or your own `$_i_php` |

Declare your own role and icon at the top of the file with `:=` (color) or `=`
(icon, so that `''` stays empty). Users and themes can then change them like any
other: `shkit set color_php '38;5;99'`.

## Slow data: background jobs

For anything slow, read a cache on every prompt and let a detached job refresh it:

```zsh
: ${SHKIT_WEATHER_TTL:=900}

function _prompt_job_weather { # FILE — detached, stdout/stderr discarded
  local data
  data=$(_prompt_timeout 5 curl -fsS 'https://wttr.in/?format=%t')
  _prompt_write $1 $data                           # atomic, stamped with the time
}

function _prompt_seg_weather {
  local file
  _prompt_key weather; file=$REPLY                 # cache path for this key
  _prompt_read $file                               # sets _ts (epoch) and _data
  (( SPAWN && EPOCHSECONDS - _ts >= SHKIT_WEATHER_TTL )) &&
    _prompt_spawn $file _prompt_job_weather $file  # at most one job per file
  [[ -d $file.lock ]] && pending+=$file            # redraw when it lands, ↻ meanwhile
  [[ -n $_data ]] || return 0
  _prompt_esc $_data
  segs+="${_c_accent}${REPLY}${_c_reset}"
}
```

| Helper | Does |
|--------|------|
| `_prompt_key NAME` | `REPLY` = the cache file for `NAME` (any string, for example a repository path) |
| `_prompt_read FILE` | sets `_ts` (when written, 0 if never) and `_data` (one line) |
| `_prompt_write FILE DATA` | writes atomically, so a prompt never reads half a file |
| `_prompt_spawn FILE CMD…` | runs `CMD` detached, once per `FILE`. A lock older than 2 minutes is dropped |
| `_prompt_timeout SECS CMD…` | `timeout` on Linux, `gtimeout` or perl on macOS. Use it for every external call |
| `$SPAWN` | set when this render may start jobs |
| `pending` | cache files whose refresh is in flight. The prompt redraws when they change |

Stamp the file first when the job can fail, as `_prompt_job_fetch` does, so a
failure retries after the TTL and not at every prompt.

## Testing

```zsh
exec zsh
shkit show                             # is {name} listed among the blocks?
shkit set -p format '{name}'           # show it alone, in one project
repeat 20 _prompt_render               # time it:
time (repeat 20 _prompt_render)        #   well under 20 × 5 ms, even in a big repository
```

For a block inside shellkit itself, add a check to `zsh/prompt.check.zsh` and run
`zsh zsh/prompt.check.zsh`. See [Development](development.md).
