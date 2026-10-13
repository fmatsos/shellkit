# Configuration

Everything specific to one machine lives outside the repository, in one directory:
`~/.config/shkit/` (`$XDG_CONFIG_HOME/shkit` if you set that). The shells call it
`$SHELL_LOCAL_DIR`. The install scripts create it with mode 700.

- [The files](#the-files)
- [Settings layers](#settings-layers)
- [Per-project settings](#per-project-settings)
- [Secrets](#secrets)
- [Drop-ins](#drop-ins)
- [Machine settings](#machine-settings)

## The files

```text
~/.config/shkit/
├── settings.sh        # machine settings: PATH, hosts, env flags (bash and zsh)
├── secrets.sh         # tokens and API keys, chmod 600 (bash and zsh)
├── aliases.sh         # your own aliases and functions (bash and zsh)
├── rc.d/*.sh          # drop-in snippets, e.g. linked from a dotfiles repo (bash and zsh)
├── rc.d/*.zsh|*.bash  # same, for one shell only
├── theme.zsh          # your prompt look (zsh)
├── projects/*.zsh     # prompt settings for one project each (zsh)
├── prompt.d/*.zsh     # prompt blocks of your own (zsh)
└── plugins/<name>/    # installed plugins, git clones (zsh)
```

Every file is optional. You rarely need to edit them by hand:
[`shkit`](shkit.md) writes `theme.zsh` and the project files, and manages
`plugins/`. Each change applies to the current shell at once.

Load order in `zshrc`:

1. options, history, keys, completion;
2. `settings.sh`, then `rc.d/*.sh` and `rc.d/*.zsh` (`*.bash` in bash), in the alphanumeric order of their names;
3. `shell/aliases.sh`, then `aliases.sh`, then the prompt, which reads `theme.zsh`, `projects/`,
   `plugins/` and `prompt.d/` (below);
4. `secrets.sh`, last.

`bashrc` follows the same order, without the prompt files.

## Settings layers

The prompt's `SHKIT_*` variables are built from five layers. Each one overrides
the layers before it:

| # | Layer | Written by |
|---|-------|-----------|
| 1 | defaults: `zsh/prompt.zsh`, then the blocks' own defaults | the repository, plugins, `prompt.d/` |
| 2 | a plugin theme, when `SHKIT_THEME=<plugin>/<theme>` is set | `shkit set theme` |
| 3 | `settings.sh` and the environment, as they were when the shell started | you |
| 4 | `theme.zsh` | `shkit set` |
| 5 | the file of the project you are in | `shkit set -p` |

So a plugin theme restyles everything you haven't set yourself. `theme.zsh` always
beats it, and a project file beats both.

`shkit show` prints what each file sets. `shkit list` prints the result, every
`SHKIT_*` in effect here.

> [!NOTE]
> Before 1.1 these settings were named `PROMPT_*`. The old names still work, in every
> layer: `PROMPT_FORMAT` in `theme.zsh` is read as `SHKIT_FORMAT`. `shkit set` renames
> them in the file it edits, and `shell/install-local.sh` renames them everywhere (it
> keeps a `.bak` of each file, and leaves bash's and zsh's own `PROMPT_COMMAND`,
> `PROMPT_DIRTRIM` and `PROMPT_EOL_MARK` alone). A block written for 1.0 that reads
> `$PROMPT_…` as it renders still gets the value; new blocks read `$SHKIT_…`.

> [!TIP]
> Put prompt *behaviour* toggles that you may also want in scripts
> (`SHKIT_SHOW_MR=false`…) in `settings.sh`. Put the *look* in `theme.zsh`.

Layers 2, 4 and 5 are read again whenever `shkit` changes something and when you
enter or leave a project. Layer 3 is read once, when the shell starts: after
editing `settings.sh`, run `exec zsh`.

## Per-project settings

A project file applies to one directory and everything below it:

```zsh
cd ~/code/acme-shop
shkit project                         # creates ~/.config/shkit/projects/acme-shop.zsh
shkit set -p format '{dir} · {git} · {mr}'
shkit set -p theme my-plugin/dark     # a plugin theme for this project only
```

Without an argument, `shkit project` uses the root of the current git repository
(its main worktree, so every worktree shares it), or `$PWD` outside git.
`shkit project DIR` picks another directory.

A project file is plain assignments, plus the directory it applies to:

```zsh
# Prompt settings for ~/code/acme-shop and below, over theme.zsh.
SHKIT_PROJECT_DIR=~/code/acme-shop
SHKIT_FORMAT='{dir} · {git} · {mr}'
```

When projects are nested, the deepest one wins. Symlinked paths are resolved, so
a project reached through a symlink still applies.

## Secrets

`secrets.sh` holds tokens and keys as plain `export` lines. It is sourced last by
both shells:

```bash
export GITLAB_TOKEN=<token>
export SLACKCLI_XOXC_TOKEN=<token>
```

- Keep it `chmod 600`. The repository's pre-commit check refuses to run otherwise.
- Code and config in the repository only ever use the variable (`"$GITLAB_TOKEN"`),
  never the value.
- `.gitignore` excludes `secrets.sh`, `settings.sh`, `*.local` and `.env*` as a
  last line of defence.

## Drop-ins

`rc.d/` takes one snippet per file, so a dotfiles repository can track them (one file linked
per snippet) without owning `settings.sh`. `*.sh` is read by both shells, `*.zsh` by zsh only,
`*.bash` by bash only. A snippet runs after `settings.sh` and before the prompt.

The file name sets the order: all the files are sorted together by name, whatever their
extension. Start a name with a number to place it, `00-vte.sh` before `10-editor.sh`; files
that share a prefix (`00-a.sh`, `00-b.zsh`) follow alphabetical order.

## Machine settings

`settings.sh` is for anything that differs between machines. Both shells read it:

```bash
export PATH="$HOME/tools/bin:$PATH"
export ENABLE_LSP_TOOL=1
export SHKIT_SHOW_MR=false        # prompt behaviour, see prompt.md
```

It is read before the prompt, so it can set any `SHKIT_*` behaviour toggle
([list](prompt.md#behaviour)) and the auto-update settings:

| Setting | Default | Effect |
|---------|---------|--------|
| `SHKIT_AUTO_UPDATE` | `true` | update shellkit to its latest release in the background, at startup |
| `SHKIT_UPDATE_TTL` | `86400` | seconds between two checks |
