# `shkit` reference

`shkit` edits the prompt settings for you and applies each change to the current
shell at once. It writes `~/.config/shkit/theme.zsh`, or the current project's
file with `-p`. Values are always written quoted, so a value never runs as code.

```text
shkit show | list
shkit set   [-p] NAME VALUE…
shkit unset [-p] NAME
shkit project [DIR]
shkit edit  [-p]
shkit plugin add [-y] URL | update [-y] [NAME] | remove NAME | list
shkit plugin new NAME [DIR] | new-block NAME [DESC] | new-theme NAME [DESC] | check [DIR]
shkit update [-y]
shkit doctor
```

Everything completes on <kbd>Tab</kbd>: subcommands, setting names, theme names
and installed plugins.

## Settings


### `shkit set [-p] NAME VALUE…`

Sets `SHKIT_<NAME>`. `NAME` is case-insensitive, and `-` or `.` count as `_`:
`color-accent`, `color_accent` and `SHKIT_COLOR_ACCENT` are the same.

```zsh
shkit set format '{dir} · {git}'
shkit set color_accent '38;5;33'
shkit set icon_dirty ''                 # an empty icon: dropped
shkit set spinner ◐ ◓ ◑ ◒               # several values = an array
shkit set theme my-plugin/dark          # a plugin theme (layer 2)
shkit set -p show_mr false              # this project only
```

`-p` writes to the file of the project you're in. It fails if there is none: create
one first with `shkit project`.

### `shkit unset [-p] NAME`

Removes the line, so the layer below applies again.

### `shkit show`

The active project, the `SHKIT_*` lines of `theme.zsh` and of the project file,
the available blocks and the installed themes.

### `shkit list`

Every `SHKIT_*` in effect here, after all [layers](configuration.md#settings-layers).
This is the full list of names `set` accepts.

### `shkit project [DIR]`

Creates, or prints, the settings file of a project: `DIR`, or else the current git
repository (every worktree shares it), or else `$PWD`. See
[per-project settings](configuration.md#per-project-settings).

### `shkit edit [-p]`

Opens `theme.zsh`, or the project file, in `$VISUAL` / `$EDITOR` (default `vi`),
then applies it.

## Plugins

See [Plugins](plugins.md) for the full story. Every `add` and `update` shows what
the plugin brings and asks before keeping it. `-y` answers yes.

| Command | Does |
|---------|------|
| `plugin add [-y] URL` | clones the repository, checks `plugin.json` and the files against the schema, lists what will be sourced, asks, then installs it as `plugins/<name>` |
| `plugin update [-y] [NAME]` | fetches, refuses rewritten history or a renamed plugin, shows the new commits and the diff stat, checks the new version, asks, fast-forwards. Without `NAME`: every plugin |
| `plugin remove NAME` | deletes the clone. Its functions stay in open shells until `exec zsh` |
| `plugin list` | name, version, description, source URL (without credentials), commit, blocks and themes |
| `plugin new NAME [DIR]` | starts a plugin repository: `plugin.json` and `git init` |
| `plugin new-block NAME [DESC]` | in a plugin repository: `blocks/NAME.zsh` from a template, declared in `plugin.json` |
| `plugin new-theme NAME [DESC]` | the same for `themes/NAME.zsh` |
| `plugin check [DIR]` | the check `add` runs, on the working tree (default: here) |

## Updating shellkit

### `shkit update [-y]`

Fetches `origin` and fast-forwards to the latest release: the `release` branch,
which only moves to a `vX.Y.Z` tag once CI has passed on it. It shows the new
commits and the diff stat first, and asks. It refuses a clone that isn't on a
branch, has commits of its own, or whose release history was rewritten upstream.
Run `exec zsh` afterwards.

The same update runs in the background at startup, once a day, only on the
default branch and without local changes. See
[Updating](installation.md#updating) for `SHKIT_AUTO_UPDATE` and `SHKIT_UPDATE_TTL`.

## Checking the setup

### `shkit doctor`

Checks what shellkit relies on, one line each: `ok`, `warn` (works, with less),
`FAIL` (broken), or `--` (not in use).

- zsh 5.8+, git 2.31+, a UTF-8 locale, an installed Nerd Font, bash 5.1+ for the fallback;
- `jq`, and `glab` / `gh` with their login;
- the docker daemon, and what sends [notifications](prompt.md#notifications);
- `~/.config/shkit` (`700`) and `secrets.sh` (`600`), an old `~/.config/shell` not
  migrated, `~/.zshrc` linked to shellkit (or `--`: [prompt only](installation.md#the-prompt-only),
  or [trying it](installation.md#try-it-first)), the prompt's cache writable;
- shellkit's version and branch, local changes that stop the auto-update, a newer
  release already fetched, the last update check;
- the theme set, and each plugin against the schema.

It only asks the network for the `glab` / `gh` login. It reports their status,
never their output. It exits with `1` when a line says `FAIL`.

## Exit status

`0` on success, `1` on a usage error, a refused plugin or a failed check. Errors
go to stderr, prefixed with `shkit:`.
