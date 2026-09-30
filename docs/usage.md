# Usage

What the shells do once installed. zsh is the main shell. bash mirrors its
options and aliases, but with a minimal prompt.

- [Jump to a directory by its name](#jump-to-a-directory-by-its-name)
- [History](#history)
- [Keys](#keys)
- [Options](#options)
- [Completion](#completion)
- [Aliases and functions](#aliases-and-functions)
- [Scripts](#scripts)
- [The bash fallback](#the-bash-fallback)

## Jump to a directory by its name

Type the last segment of a directory you visited before, alone on the line:

```console
$ acme-shop
$ pwd
/home/me/code/acme-shop
```

The most recently visited directory with that name wins. The line is rewritten
to `cd /home/me/code/acme-shop` before it runs, so the history records the real path.

A word that is a command, an alias, a function or a directory in the current
directory keeps its usual meaning. The list of visited directories is
`~/.cache/zsh/recent-dirs` (the last 500, via zsh's `cdr`).

`AUTO_CD` is on too: `www` alone is `cd www`, and `..` is `cd ..`.

## History

- **One unlimited history**, written as you go (`INC_APPEND_HISTORY`), so a new tab
  sees the commands of the others.
- **Duplicates are dropped**. A command starting with a space isn't recorded.
  `exit`, `ls`, `bg`, `fg`, `history` and `clear` are never recorded.
- **<kbd>↑</kbd> / <kbd>↓</kbd> search** the history for what is already typed.
- **`!!` and other expansions** are shown for review before they run (`HIST_VERIFY`).
- Commands keep their timestamp (`EXTENDED_HISTORY`): `history -i` shows it.

## Keys

| Key | Action |
|-----|--------|
| <kbd>Esc</kbd> <kbd>Esc</kbd> | toggle `sudo ` in front of the line; on an empty line, the last command with `sudo` |
| <kbd>↑</kbd> / <kbd>↓</kbd> | history search on the current prefix |
| <kbd>Tab</kbd> | completion menu (arrow keys to pick), with one typo forgiven |

Key bindings are Emacs style (`bindkey -e`).

## Options

| Option | Effect |
|--------|--------|
| `NO_CLOBBER` | `>` never overwrites an existing file: use `>|` when you mean it |
| `AUTO_CD` | a directory name alone changes into it |
| `INTERACTIVE_COMMENTS` | `# comments` work on the command line |
| recursive `**` | `ls **/*.php` walks subdirectories (built into zsh, `globstar` in bash) |
| colored `man` | bold, underlined and highlighted text in color |

## Completion

- Case-insensitive, with a selection menu, and one typo fixed on <kbd>Tab</kbd>
  (`cd Dwonloads` → `Downloads`).
- **Generated completions** for `codex`, `symfony`, `npm` and `composer`, created by
  the install scripts. Run them again after upgrading one of those tools.
- **`aws`** through `aws_completer` when it is installed.
- **`git task <prefix>`** completes the local branches whose last segment starts
  with `<prefix>`, case-insensitive: `feature/SHOP-42_checkout` matches `shop-42`.

## Aliases and functions

Defined in `shell/aliases.sh`, the same in bash and zsh.

| Name | Does |
|------|------|
| `ll` / `l` / `la` | `ls -lAFh` / `ls -lha` / `ls -lhA`, colored on Linux and macOS |
| `cp`, `mv` | interactive and verbose (`-iv`) |
| `mkdir` | creates parents, verbose (`-pv`) |
| `grep` | colored, skips `.git` and other VCS directories |
| `less` | `-FSRXc`: quits if the output fits, keeps colors, no line wrap |
| `wget` | resumes (`-c`) |
| `gs` | `git switch` |
| `gpf` | `git push --force-with-lease` |
| `gclean` | `git-cleanup --verbose` |
| `dstop` | stops every running Docker container |
| `rmc` / `rml` | in a Symfony project, delete `var/cache` / `var/log` (uses `sudo`) |

Aliases and functions for one machine only go in `~/.config/shkit/aliases.sh`,
which both shells source right after `shell/aliases.sh`. It is never committed.

> [!NOTE]
> Because `cp`, `mv` and `mkdir` are aliases, a script *sourced* into the shell
> should call `command mkdir` and the like. Scripts that are *executed* (with a
> shebang) don't see aliases.

## Scripts

`bin/` holds standalone scripts. The install scripts don't install them: put
`bin/` in your `PATH`, or link the ones you want into `~/.local/bin` (already in
`PATH`).

| Script | Does |
|--------|------|
| `usephp 8.2` | points `~/.bin/php` at PHP 8.2 (Debian's `php8.2` or Homebrew's `php@8.2`), falling back to the default `php` |

## The bash fallback

`bash/bashrc` has the same options (`autocd`, `cdspell`, `dirspell`, `globstar`,
`noclobber`), the same unlimited shared history with prefix search, <kbd>Esc</kbd>
<kbd>Esc</kbd> for `sudo`, colored `man` and the same aliases.

Its prompt is deliberately minimal: the directory, the git branch (through git's
own `__git_ps1`) and a `$` that turns red when the last command failed. The full
prompt, `shkit` and the directory jump are zsh only.
