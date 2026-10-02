# Installation

- [Requirements](#requirements)
- [Try it first](#try-it-first)
- [Install](#install)
- [The prompt only](#the-prompt-only)
- [macOS notes](#macos-notes)
- [Updating](#updating)
- [Moving to another machine](#moving-to-another-machine)
- [Migrating from an older layout](#migrating-from-an-older-layout)
- [Uninstalling](#uninstalling)

## Requirements

| Tool | Needed for | Linux | macOS |
|------|------------|-------|-------|
| zsh 5.8+ (tested: 5.9) | the default shell | `apt install zsh` (or dnf / pacman) | built in |
| git 2.31+ | the `{git}` block, plugins | usually there | Command Line Tools or `brew install git` |
| jq | `{mr}` on GitLab, `shkit plugin` | `apt install jq` (missing from minimal installs) | built in since macOS 15, `brew install jq` before |
| perl | job timeouts when `timeout` is missing | usually there | built in |
| bash 5.1+ | the bash fallback only | usually there | `brew install bash bash-completion@2` |
| `glab` / `gh` | `{mr}`: merge / pull request and its CI | optional | optional |
| docker | `{docker}` | optional | Docker Desktop or OrbStack |

Without jq, everything works except `{mr}` on GitLab and plugins. Without
`glab` / `gh` / docker, their blocks just stay hidden.

Icons use [Nerd Font](https://www.nerdfonts.com) glyphs. Either use a Nerd Font
in your terminal, or add *Symbols Nerd Font* as a fallback font. You can also set
the icons you can't display to `''` (see [The prompt](prompt.md#icons)).

## Try it first

```bash
git clone https://github.com/fmatsos/shellkit.git ~/shellkit
~/shellkit/zsh/try.sh               # exit to leave
~/shellkit/zsh/try.sh -c 'shkit doctor'
```

`zsh/try.sh` starts a zsh on the repository's `zshrc` without installing anything.
Its settings (`shkit set`…), history and caches go to a temporary directory,
deleted when the shell exits. `~/.zshrc`, your history and `~/.config` are left
alone, and the automatic update is off.

## Install

Clone the repository anywhere and run the install script of each shell you use:

```bash
git clone https://github.com/fmatsos/shellkit.git ~/shellkit
~/shellkit/zsh/install.sh    # zsh: the default shell
~/shellkit/bash/install.sh   # bash: the fallback (optional)
exec zsh
```

`zsh/install.sh`:

1. symlinks `~/.zshrc` and `~/.zshenv` to the repository. An existing file is
   kept as `~/.zshrc.pre-config`;
2. creates `~/.config/shkit/` (chmod 700), your [local configuration](configuration.md);
3. generates completions for `codex`, `symfony`, `npm` and `composer` when they are
   installed;
4. imports `~/.bash_history` into `~/.zsh_history` once, only if the zsh history
   doesn't exist yet.

Then `shkit doctor` checks the result: versions, locale, font, tools and files.

`bash/install.sh` symlinks `~/.bashrc` (an existing file is kept as
`~/.bashrc.pre-config`), generates the same completions for bash and, on macOS,
creates a `~/.bash_profile` that sources it.

Both scripts can be run again at any time, for example after upgrading one of
the tools above to refresh its completion.

To make zsh your login shell:

```bash
chsh -s "$(command -v zsh)"
```

## The prompt only

To keep your own `~/.zshrc` (options, plugins, aliases) and only take the prompt,
skip `install.sh` and add this line to it, after `compinit` if you run it, and
instead of any other prompt (Oh My Zsh theme, starship, powerlevel10k…):

```zsh
source ~/shellkit/zsh/prompt.zsh
```

You get the whole prompt, its blocks, themes, plugins and per-project settings, and
`shkit`, which creates `~/.config/shkit/` on its first `shkit set`. The automatic
update works the same. What stays out is what `zshrc` adds: its options, history,
completion setup, aliases and the [shell features](usage.md). `shkit doctor`
reports this mode as `prompt only`.

## macOS notes

- **Homebrew** is found in `/opt/homebrew` (Apple silicon) and `/usr/local` (Intel).
  It is added to `PATH` and `fpath` directly, without running `brew shellenv` at
  every start.
- **`compinit` "insecure directories"**: Homebrew's zsh directories are
  group-writable. `zsh/install.sh` removes that write bit so completion loads
  without asking.
- **Bash**: `/bin/bash` is 3.2, too old for `bashrc`. With it, `bashrc` prints a
  message and stops. Install bash 5 with Homebrew and use that one. The install
  scripts themselves run on 3.2.
- **Locale**: a terminal started from a GUI app may have no locale. `zshrc` then
  sets `LC_CTYPE` to UTF-8 so the icons display.
- **Terminal.app** keeps one history per tab by default. `zshenv` turns that off,
  so every tab shares one history.

## Updating

shellkit updates itself. At shell startup, at most once a day, a background job
looks for the latest release and fast-forwards to it. A release is a `vX.Y.Z` tag
that passed the CI on Linux and macOS. Startup doesn't wait for the job, and nothing
is printed until the next shell, which says once:

```text
shellkit updated: v1.1.0 -> v1.2.0 (exec zsh in the shells already open)
```

The job leaves the clone alone when:

- it has local changes, or commits the release doesn't have;
- it isn't on the default branch (`main`);
- the release history was rewritten upstream (fetch refuses it).

A tag whose CI failed, and a pre-release (`v2.0.0-rc.1`), are never installed.

To update right away, see what comes and confirm:

```zsh
shkit update          # shows the commits, asks; -y: don't ask (any branch)
exec zsh
```

To turn the automatic update off, or check less often, set this in `settings.sh`:

```bash
export SHKIT_AUTO_UPDATE=false     # default true
export SHKIT_UPDATE_TTL=604800     # seconds between two checks, default 86400 (a day)
```

A clone you develop in (commits ahead of the latest tag) is never touched: use
`git pull`. Run the install scripts again only when the release notes say so.

Plugins are updated separately and only on request, with
`shkit plugin update` (see [Plugins](plugins.md#updating)).

## Moving to another machine

The repository holds everything shared. Everything specific to a machine lives
in `~/.config/shkit/` and is never committed. Copy that directory yourself, keeping
its permissions:

```bash
rsync -a ~/.config/shkit/ other-host:.config/shkit/
ssh other-host chmod 600 .config/shkit/secrets.sh
```

## Migrating from an older layout

- **`~/.config/shell/`** (before the project was named shellkit): the install
  scripts, or `shell/install-local.sh` alone, move it to `~/.config/shkit/`. Until
  then, each new shell prints a reminder. If both directories exist, nothing is
  moved: merge them by hand.
- **`~/.settings.local`, `~/.secrets.local`, `~/.theme.local`, `~/.prompt.d/`**:
  moved into `~/.config/shkit/` the same way.

```bash
bash ~/shellkit/shell/install-local.sh
exec zsh
```

## Uninstalling

```bash
rm ~/.zshrc ~/.zshenv ~/.bashrc              # the symlinks
mv ~/.zshrc.pre-config ~/.zshrc              # if you had one before
mv ~/.bashrc.pre-config ~/.bashrc
```

`~/.config/shkit/` holds your settings and secrets: keep it or delete it.
