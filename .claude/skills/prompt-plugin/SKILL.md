---
name: prompt-plugin
description: Create or change a zsh prompt plugin — a git repository of prompt blocks and themes that shkit plugin add installs. Scaffold it (shkit plugin new / new-block / new-theme), write a block or a theme, validate it against zsh/plugin/schema.json, test it locally, version and publish it. Use when the user wants to make, extend or fix a prompt plugin, or asks how one must be laid out.
---

# Writing a prompt plugin

A plugin is its own git repository. Its layout is fixed by
`zsh/plugin/schema.json` (this repo), and `shkit` refuses any other layout,
on `add` and on each `update`:

```
plugin.json          # name, version, description, the declared blocks and themes
blocks/<name>.zsh    # one per declared block: defines _prompt_seg_<name>, shown as {name}
themes/<name>.zsh    # one per declared theme: PROMPT_* assignments
```

Other files (README, LICENSE, tests, CI) are free. `zsh/plugin/example/` is a
complete, valid one to read.

## Steps

Let `shkit` write the layout: it keeps `plugin.json` and the files in step.

1. `shkit plugin new NAME [DIR]`: `plugin.json` + `git init`. NAME is
   `[a-z0-9-]`, it becomes the install directory and the theme prefix
   (`PROMPT_THEME=NAME/<theme>`), and it can never change: an update that renames
   the plugin is refused.
2. In the repository:
   - `shkit plugin new-block NAME 'what it shows'`: `blocks/NAME.zsh` from a
     template, plus its entry in `plugin.json`. NAME is `[a-z0-9_]`.
   - `shkit plugin new-theme NAME 'description'`: `themes/NAME.zsh`, same.
   - To remove one, delete its file **and** its entry in `plugin.json`.
3. Write the block or theme (below). Fill `plugin.json` by hand where it helps:
   `description`, `author`, `license`, `homepage`, `repository`, `keywords`, and
   `requires` (commands the blocks run: users are told which are missing). Any
   other key is refused.
4. `shkit plugin check`: the same check as `add`, on the working tree.
5. Test it for real (below), then commit, add a remote, and push.
6. The user installs it with `shkit plugin add <URL>`, and picks a theme with
   `shkit set theme NAME/<theme>` (`-p`: one project).

## A block

Same contract as a built-in segment (the `prompt-theme` skill has the engine):

```zsh
# blocks/php.zsh -> {php}
: ${PROMPT_COLOR_PHP:='38;5;104'} ${PROMPT_ICON_PHP=$''}   # own defaults, overridable
function _prompt_seg_php {
  [[ -f composer.json ]] || return 0              # nothing appended = block hidden, its separator too
  local v='?'; [[ -r .php-version ]] && v=$(<.php-version)
  _prompt_esc $v                                  # every dynamic text
  segs+="${_c_php}${_i_php} ${REPLY}${_c_reset}"  # colors $_c_<role>, icons $_i_<name>, never literals
}
```

- **Runs at every prompt**: it has to stay local and fast, a few ms at most. A
  network call, or anything slower, goes through the background cache:
  - `_prompt_key NAME`, then `_prompt_read FILE` (sets `_ts`, `_data`);
  - when `SPAWN` is set and the TTL has passed: `_prompt_spawn FILE _prompt_job_<name> ARGS…`
    and `pending+=FILE`;
  - the job ends with `_prompt_write FILE DATA`;
  - every call it makes: `_prompt_timeout SECS cmd…`.

  A slow block slows every prompt of every user: time it with
  `repeat 20 _prompt_render` in a large repository.
- **Injection**: text from outside (a branch, a file, an API) goes through
  `_prompt_esc`, never through `eval` or `$(…)`. `PROMPT_SUBST` stays off.
- **Sourced inside a function, and again after each `shkit plugin` change**:
  - a global needs `typeset -g` (a bare `typeset` makes a local);
  - keep it idempotent: only defaults with `: ${X:=…}`, functions, no side effects.
- **Linux and macOS**: no GNU-only flag, no `/proc` without a fallback, `timeout`
  through `_prompt_timeout` (AGENTS.md, Rule #2).
- **No secret in the repository**: a block reads a variable (`$GITLAB_TOKEN`) that
  the user sets in `~/.config/shkit/secrets.sh`, never a value.
- **The file defines `_prompt_seg_<name>` for its own name.** The check greps for it.
  A block named like a built-in (`docker`) overrides it: say so in the description.

## A theme

`PROMPT_*` assignments only: `PROMPT_FORMAT`, `PROMPT_RIGHT_FORMAT`, `PROMPT_SEPARATOR`,
`PROMPT_COLOR_<ROLE>`, `PROMPT_ICON_<NAME>`, `PROMPT_SPINNER`. `shkit list`
shows every name. Plain `NAME=value` lines, no commands.

A theme sits under the user's `theme.zsh` and project files, which always win. So
a theme can set a format using its plugin's blocks, but the user keeps the last word.

## Testing it locally

- `shkit plugin check` after each change.
- `add` clones, so it needs a commit:
  - commit, then `shkit plugin add -y /path/to/repo`;
  - `format '{NAME}'` shows the block: `shkit set -p format '{NAME}'` in a
    project, or `set` without `-p`;
  - after the next commit: `shkit plugin update -y NAME`.
- `shkit plugin remove NAME` when done. Its functions stay in the open shells
  until `exec zsh`.
- CI of the plugin repository: `jq -r --slurpfile schema schema.json -f
  validate.jq plugin.json` prints one error per line, nothing when valid. Copy both
  files from `zsh/plugin/`.

## Releasing

- Bump `version` (semver) with every change users will get.
- Never rewrite published history (force push, amend, rebase of `main`): `update`
  refuses it, and users would have to remove and add the plugin again.
- Users get changes only when they run `shkit plugin update`. It shows them
  the new commits and the diff, then asks: keep commits small and their messages
  clear.
