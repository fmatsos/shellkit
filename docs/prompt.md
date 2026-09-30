# The prompt

`zsh/prompt.zsh` draws two lines: an info line with every fact, then the input line,
which holds only the `$`.

<p align="center">
  <img src="assets/prompt.png?v=3" alt="The shellkit prompt in a git repository: directory, branch, 1 commit ahead, 2 changed files with +15 −4 lines, merge request !482 with CI passed, and at the right end of the line 1 Claude agent and the 5 h / 7 d quota; below, the input line with only the $" width="100%">
</p>

<sub>Rendered from the real prompt, 96 columns wide, for a demo project: the default theme and `PROMPT_FORMAT='{dir} · {git} · {mr}'`.</sub>

- [How it stays fast](#how-it-stays-fast)
- [Built-in blocks](#built-in-blocks)
- [Format](#format)
- [Colors](#colors)
- [Icons](#icons)
- [Behaviour](#behaviour)
- [Tab title](#tab-title)
- [Security](#security)

## How it stays fast

Each prompt only computes local facts: the directory, `git status`, files on disk.
That stays under 50 ms even in a 35,000-file repository.

Anything that needs the network or a slow command is read from a cache under
`$XDG_RUNTIME_DIR` (`$TMPDIR` on macOS):

- `git fetch`, for a true behind count;
- the merge / pull request and its CI, through `glab` / `gh`;
- `docker ps`.

When a cache entry is older than its TTL, a background job refreshes it and a
muted `↻` shows. When the job finishes, the prompt redraws in place, without
pressing Enter. Every job has a timeout, and only one runs per cache entry.

## Built-in blocks

| Block | Shows | Source |
|-------|-------|--------|
| `{dir}` | the current directory, in full | local |
| `{git}` | branch (`wt` in a linked worktree), ahead ⇡ / behind ⇣, changed files with `+added −removed` lines, an operation in progress (`rebase 2/5`, `merge`, `cherry-pick`, `revert`, `bisect`) with its conflicts | local, plus a background `git fetch` |
| `{mr}` | the open or merged merge / pull request of the branch: `!123` (GitLab) or `#123` (GitHub), a link in terminals that support it, `draft` or `merged`, and the CI status (`✓` passed, `✗` failed, `●` running, `○` skipped) | `glab` (GitLab) or `gh` (GitHub), cached. Needs `{git}` before it |
| `{docker}` | anomalies only: unhealthy, restarting or dead containers, or a failed container in a compose stack that is otherwise up | `docker ps`, cached |
| `{agents}` | live Claude Code sessions, and how many are busy | `~/.claude/sessions`, local |
| `{quota}` | Claude usage for the 5 h and 7 d windows, colored low → high, with the reset time once past `PROMPT_QUOTA_RESET_AT` % | a file written by the Claude Code status line, local |

A block with nothing to say shows nothing, and neither do the separators around
it. You can [write your own](blocks.md) or get them from [plugins](plugins.md).
`shkit show` lists every block available.

## Format

Two settings lay the prompt out:

```zsh
PROMPT_FORMAT='{dir} · {git} · {mr} · {docker}'   # the info line (default)
PROMPT_RIGHT_FORMAT='{agents} · {quota}'           # right end of the info line (default)
```

A format is `{block}` placeholders and literal text:

- **Text between two blocks is a separator.** It shows only when a block on each
  side shows something.
- **Text before the first block or after the last one** always shows.
- **Literal text is printed as is**, in the `MUTE` color. `%` has no special meaning.
- **An unknown `{name}`** shows nothing.

```zsh
shkit set format '[{git}] {dir}'
shkit set right_format ''            # nothing on the right
```

The right part is aligned to the terminal's right edge and follows its width when you
resize the window. If both parts can't fit on one line, the right part is left out.

`PROMPT_SEPARATOR` (default `' · '`) separates the parts *inside* a block, for
example the branch, its status and a rebase in `{git}`.

The input line is `PROMPT_ICON_PROMPT` (default `$`) in the `PRIMARY` color, and
in bold `FAIL` after a failed command.

## Colors

Blocks never use color codes directly. They use **roles**, and each role is an
[SGR code](https://en.wikipedia.org/wiki/ANSI_escape_code#SGR):
`'1;32'` (bold green), `'38;5;33'` (256-color), `'38;2;255;128;0'` (true color).

| Role | Default | Used for |
|------|---------|----------|
| `PROMPT_COLOR_PRIMARY` | `1;32` | the directory, the `$` |
| `PROMPT_COLOR_ACCENT` | `36` | branch, ahead, busy agents |
| `PROMPT_COLOR_MUTE` | `38;5;248` | separators, literal text, secondary info |
| `PROMPT_COLOR_WARN` | `38;5;208` | behind, changed files, an operation in progress, docker |
| `PROMPT_COLOR_ADDED` | `38;5;114` | added lines |
| `PROMPT_COLOR_REMOVED` | `38;5;174` | removed lines |
| `PROMPT_COLOR_OK` | `32` | CI passed |
| `PROMPT_COLOR_FAIL` | `31` | CI failed, conflicts, the `$` after an error |
| `PROMPT_COLOR_RUN` | `34` | CI running |
| `PROMPT_COLOR_AGENT` | `38;5;173` | Claude sessions |
| `PROMPT_COLOR_QUOTA_5H` / `_7D` | `38;5;141` / `38;5;99` | quota labels |
| `PROMPT_QUOTA_PALETTE` | 15 × 256-color codes | quota percentage, low → high (an array) |

```zsh
shkit set color_accent '38;5;33'
shkit set quota_palette 108 150 185 227 221 215 209 167
```

A block may add its own role, for example `PROMPT_COLOR_PHP`.

## Icons

Every icon is a variable. Set one to `''` to drop it.

| Icon | Default | | Icon | Default |
|------|---------|-|------|---------|
| `PROMPT_ICON_DIR` | none (for example `$'\uf07b'`, a folder) | | `PROMPT_ICON_DIRTY` | Nerd Font pencil |
| `PROMPT_ICON_BRANCH` | none (for example `$'\ue0a0'`, a branch) | | `PROMPT_ICON_ADDED` / `_REMOVED` | `+` / `−` |
| `PROMPT_ICON_GITLAB` / `_GITHUB` | Nerd Font logos | | `PROMPT_ICON_CONFLICT` | `✗` |
| `PROMPT_ICON_DOCKER` | Nerd Font whale | | `PROMPT_ICON_CI_OK` / `_FAIL` | `✓` / `✗` |
| `PROMPT_ICON_AGENT` | `✻` | | `PROMPT_ICON_CI_RUN` / `_SKIP` | `●` / `○` |
| `PROMPT_ICON_AHEAD` / `_BEHIND` | `⇡` / `⇣` | | `PROMPT_ICON_REFRESH` | `↻` |
| `PROMPT_ICON_PROMPT` | `$` | | `PROMPT_SPINNER` | braille frames (an array) |

```zsh
shkit set icon_branch $'\ue0a0'     # a branch glyph before the branch name
shkit set icon_agent '🤖'
```

The Nerd Font glyphs need a [Nerd Font](https://www.nerdfonts.com), or *Symbols
Nerd Font* as a fallback font in your terminal.

## Behaviour

These are best set in `settings.sh`, or with `shkit set`:

| Setting | Default | Effect |
|---------|---------|--------|
| `PROMPT_SHOW_MR` | `true` | query `glab` / `gh` for `{mr}` |
| `PROMPT_AUTO_FETCH` | `true` | background `git fetch` for an up-to-date behind count |
| `PROMPT_TITLE_SPINNER` | `true` | animate the tab title while a refresh runs |
| `PROMPT_FETCH_TTL` | `300` | seconds between two fetches of a repository |
| `PROMPT_MR_TTL` | `120` | seconds between two MR / PR lookups (20 s while CI runs) |
| `PROMPT_DOCKER_TTL` | `30` | seconds between two `docker ps` |
| `PROMPT_DIFF_MAX_FILES` | `50` | above this many changed files, skip the `+/−` line count |
| `PROMPT_QUOTA_RESET_AT` | `80` | from this %, `{quota}` also shows when the window resets |
| `PROMPT_QUOTA_FILE` | `~/.cache/claude-quota` | where `{quota}` reads from |

A fetch never runs during a rebase or other operation in progress, never asks
for credentials, and gives up after 60 s.

## Tab title

The terminal tab shows the full current path, even in `$HOME`. While a refresh
runs, `PROMPT_SPINNER` frames animate in front of it. Turn that off with
`PROMPT_TITLE_SPINNER=false`.

## Security

`PROMPT_SUBST` stays off, and every dynamic text (branch names, file contents,
API answers) is escaped before it reaches the prompt. A branch named
`$(rm -rf ~)` or `%F{red}` is printed as is, never run or interpreted.
