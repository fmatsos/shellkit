# Writing a theme

A theme is a set of `PROMPT_*` assignments: layout, colors, icons. It can live in
two places:

| Where | For | Applied |
|-------|-----|---------|
| `~/.config/shkit/theme.zsh` | your own look, on this machine | always (layer 4) |
| `themes/<name>.zsh` in a [plugin](plugins.md) | a look to share | when `PROMPT_THEME=<plugin>/<name>` (layer 2) |

See [settings layers](configuration.md#settings-layers) for how they stack.

## Your own look

The quickest way is `shkit`. Every change applies at once:

```zsh
shkit set format '{dir} · {git} · {mr}'
shkit set right_format '{quota}'
shkit set color_primary '1;34'
shkit set color_accent '38;5;110'
shkit set icon_dir ''
```

This writes `~/.config/shkit/theme.zsh`, which you can also edit directly
(`shkit edit`):

```zsh
# ~/.config/shkit/theme.zsh
PROMPT_FORMAT='{dir} · {git} · {mr}'
PROMPT_RIGHT_FORMAT='{quota}'
PROMPT_COLOR_PRIMARY='1;34'
PROMPT_COLOR_ACCENT='38;5;110'
PROMPT_ICON_DIR=''
```

## A theme file

A theme file follows the same rules, whether it is `theme.zsh` or a plugin's `themes/<name>.zsh`:

- **Only `NAME=value` lines** and comments: no commands, no `$(…)`, no conditions.
  The file is sourced at every settings change, inside a function.
- **Only `PROMPT_*` names.** `shkit list` shows every one in effect.
- **Arrays** use parentheses: `PROMPT_SPINNER=(◐ ◓ ◑ ◒)`.
- **Quote values**: `PROMPT_COLOR_MUTE='38;5;244'`.
- **Leave out what you don't change.** Anything unset keeps its default, or the
  value from the layer below.

```zsh
# themes/nord.zsh — cool blues, one warm accent for warnings.
PROMPT_FORMAT='{dir} {git} {mr}'
PROMPT_SEPARATOR=' '
PROMPT_COLOR_PRIMARY='1;38;2;136;192;208'
PROMPT_COLOR_ACCENT='38;2;129;161;193'
PROMPT_COLOR_MUTE='38;2;76;86;106'
PROMPT_COLOR_WARN='38;2;235;203;139'
PROMPT_COLOR_OK='38;2;163;190;140'
PROMPT_COLOR_FAIL='38;2;191;97;106'
PROMPT_ICON_PROMPT='❯'
```

The variables you can set:

| Group | Names | Reference |
|-------|-------|-----------|
| layout | `PROMPT_FORMAT`, `PROMPT_RIGHT_FORMAT`, `PROMPT_SEPARATOR` | [Format](prompt.md#format) |
| colors | `PROMPT_COLOR_<ROLE>`, `PROMPT_QUOTA_PALETTE` | [Colors](prompt.md#colors) |
| icons | `PROMPT_ICON_<NAME>`, `PROMPT_SPINNER` | [Icons](prompt.md#icons) |

Behaviour toggles (`PROMPT_SHOW_MR`, TTLs…) belong to the user, not to a theme.

## Tips

- **Colors are roles**: change `ACCENT` and every block using it follows. A block
  from a plugin may add its own role (`PROMPT_COLOR_PHP`), which a theme can set
  too.
- **Stay readable on both light and dark terminals**, or say which one the
  theme is for in its description.
- **256-color codes** (`38;5;N`) work almost everywhere. True color
  (`38;2;R;G;B`) needs a terminal that supports it.
- **Try it on a project first**: `shkit project`, then `shkit set -p …`. Only
  that project changes.
- **A format can use a plugin's blocks**: `{php}` shows nothing where the block
  isn't installed.

## Sharing a theme

Put it in a plugin repository:

```zsh
shkit plugin new my-themes && cd my-themes
shkit plugin new-theme nord 'Cool blues, warm warnings'
$EDITOR themes/nord.zsh
```

Then follow [Plugins → writing one](plugins.md#writing-a-plugin). Users pick it with
`shkit set theme my-themes/nord`.
