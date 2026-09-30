<p align="center">
  <img src="docs/assets/banner.png" alt="shellkit: a hermit crab in sunglasses, holding a wrench and a screwdriver, on a beach" width="100%">
</p>

<p align="center">
  <a href="https://github.com/fmatsos/shellkit/actions/workflows/check.yml"><img src="https://github.com/fmatsos/shellkit/actions/workflows/check.yml/badge.svg" alt="check"></a>
  <img src="https://img.shields.io/badge/Linux-supported-success?logo=linux&logoColor=white" alt="Linux: supported">
  <img src="https://img.shields.io/badge/macOS-supported-success?logo=apple&logoColor=white" alt="macOS: supported">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-Unlicense-blue" alt="License: Unlicense"></a>
</p>

A plain zsh / bash setup for Linux and macOS, with an async, themeable prompt
that keeps every fact on one line and never makes you wait for the network.
There's no framework (no Oh My Zsh, no Oh My Bash) and zsh starts in about 35 ms.

<p align="center">
  <img src="docs/assets/prompt.png?v=3" alt="The shellkit prompt in a git repository: directory, branch, 1 commit ahead, 2 changed files with +15 −4 lines, merge request !482 with CI passed, and at the right end of the line 1 Claude agent and the 5 h / 7 d quota; below, the input line with only the $" width="100%">
</p>

## Features

- **Async prompt**: local facts are shown right away. Networked data (`git fetch`,
  the merge / pull request and its CI, unhealthy containers) is fetched in the
  background, and the prompt redraws in place when it arrives. You don't need to
  press Enter.
- **Git at a glance**: branch, worktree, ahead / behind, dirty files with a diff
  stat, and a rebase / merge / cherry-pick / bisect in progress with its conflicts.
  Also the ticket of the branch, and the review of its merge / pull request.
- **Built-in blocks that stay quiet**: a compose stack's health, how long the last
  command took, why it failed, `user@host` over SSH. Each shows only when it has
  something to say.
- **Long commands notify you**: a desktop notification when one ends after 30 s.
- **Themes and blocks**: the layout is a format string such as `'{dir} · {git}'`.
  Colors are roles, icons are variables, and a block is a small zsh function.
- **Per-project settings**: another format or palette for one repository and
  everything below it.
- **Plugins**: blocks and themes shared as git repositories. Each is checked
  against a JSON schema, and nothing is fetched or run until you confirm.
- **`shkit`**: one command to change settings, create project files, manage
  plugins and check the setup (`shkit doctor`). It applies every change immediately, so you never edit shell files by hand.
- **Shell comforts**: jump to a visited directory by its name, Esc Esc toggles
  `sudo`, an unlimited shared history with prefix search, and colored `man`.
- **Self-updating**: a background job at startup moves to the latest release,
  at most once a day. Only versions that passed CI are installed, and local changes
  are never touched.
- **Bash fallback**: the same options and aliases, with a deliberately minimal prompt.
- **Secrets stay out**: machine-specific settings and tokens live in
  `~/.config/shkit/`, never in the repository.

## Quick start

```bash
git clone git@github.com:fmatsos/shellkit.git ~/shellkit
~/shellkit/zsh/install.sh      # links ~/.zshrc and ~/.zshenv, creates ~/.config/shkit
exec zsh
```

Then shape the prompt:

```zsh
shkit set format '{dir} · {git} · {mr}'   # the info line
shkit set color_accent '38;5;33'           # a color role (an SGR code)
shkit project                              # settings for this repository only…
shkit set -p format '{dir} · {git}'        # …used here and below
shkit show                                 # what is set, where
```

A [Nerd Font](https://www.nerdfonts.com) is recommended for the icons. Symbols
Nerd Font is enough as a fallback font.

## Documentation

| Guide | What's in it |
|-------|--------------|
| [Installation](docs/installation.md) | requirements, Linux and macOS, bash fallback, automatic updates, migrating |
| [Usage](docs/usage.md) | the shell features, aliases and scripts |
| [Configuration](docs/configuration.md) | `~/.config/shkit/`, settings layers, per-project settings, secrets |
| [`shkit` reference](docs/shkit.md) | every command and option |
| [The prompt](docs/prompt.md) | built-in blocks, format syntax, colors, icons, behaviour |
| [Writing a theme](docs/themes.md) | a look of your own, locally or in a plugin |
| [Writing a block](docs/blocks.md) | a new `{segment}`: the contract, background jobs |
| [Plugins](docs/plugins.md) | installing, writing and publishing one; the manifest |
| [Development](docs/development.md) | repository layout, checks, CI, releasing |

## Requirements

| | Linux | macOS |
|---|---|---|
| shell | zsh 5.8+ (bash 5.1+ for the fallback) | the system zsh; `brew install bash` for the fallback |
| `git` | ✓ | ✓ (Command Line Tools or Homebrew) |
| `jq` | `apt install jq` | built in since macOS 15, `brew install jq` before |
| optional | `glab` / `gh` (MR / PR and CI), `docker` | same, via Homebrew |

No GNU coreutils are needed on macOS. See [Installation](docs/installation.md).

## License

Public domain, see [LICENSE](LICENSE) ([Unlicense](https://unlicense.org)).
