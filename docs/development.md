# Development

Working on shellkit itself. The rules for contributors, human or agent, are in
[`AGENTS.md`](../AGENTS.md). This page is the tour.

- [Repository layout](#repository-layout)
- [Principles](#principles)
- [Checks](#checks)
- [CI](#ci)
- [Releasing](#releasing)
- [Agent skills](#agent-skills)

## Repository layout

| Path | Role |
|------|------|
| `zsh/zshrc`, `zsh/zshenv` | the zsh config, symlinked by `zsh/install.sh` |
| `zsh/prompt.zsh` | the prompt: blocks, background jobs, layers, rendering |
| `zsh/prompt.check.zsh` | its self-check (no network) |
| `zsh/shkit.zsh` | the `shkit` command, its completion, the auto-update |
| `zsh/plugin/` | `schema.json`, `validate.jq` and `example/`, a template plugin |
| `bash/bashrc`, `bash/completion.sh` | the bash fallback |
| `shell/aliases.sh` | aliases and functions shared by both shells |
| `shell/install-local.sh` | creates and migrates `~/.config/shkit/` |
| `bin/` | standalone scripts |
| `docs/` | this documentation |
| `.github/workflows/` | `check.yml` (CI) and `release.yml` (releases) |
| `.github/smoke.zsh`, `.github/smoke.bash` | the installed shells, tested end to end in CI |
| `.claude/skills/` | agent skills (below), including `config-commit/check.sh` |

## Principles

- **Plain shell, no framework.** Startup stays under 60 ms (`check.sh`), and around 35 ms is usual. The README's speed
  table comes from `.github/bench/run.sh` (zsh-bench, in Docker).
- **Linux and macOS, fully.** No GNU-only flags, no `/proc` without a fallback. A
  zsh builtin (`zstat`, `$EPOCHREALTIME`, `:A`) is better than an `$OSTYPE` branch,
  because then Linux runs the Mac's code too. The install scripts must run on
  macOS's bash 3.2.
- **The prompt's synchronous path stays local**: under 50 ms in a large repository.
  Anything networked goes through the background cache.
- **Nothing dynamic reaches the prompt unescaped**, and `PROMPT_SUBST` stays off.
- **No secret in the repository, ever.** The code uses variables, and the values
  live in `~/.config/shkit/secrets.sh`.
- **`noclobber` is on**: overwrite a file with `>|`.

## Checks

Run before every commit, after `git add`:

```bash
.claude/skills/config-commit/check.sh
```

| Check | What |
|-------|------|
| syntax | `zsh -n` / `bash -n` / `sh -n` on every script |
| prompt self-check | `zsh/prompt.check.zsh`: blocks, layers, `shkit`, plugins, updates. It forces the macOS fallbacks on Linux too (no `timeout`, no `/proc`) |
| startup | the working tree's `zshrc` prints nothing on stderr, and starts in ≤ 60 ms (best of 5) |
| secrets | the exact values of your `secrets.sh`, then common token shapes, in the index |

Exit code 1 means don't commit. To run the self-check alone:

```bash
zsh zsh/prompt.check.zsh
```

## CI

`.github/workflows/check.yml` runs on every push to a branch and on every pull
request, on Ubuntu and macOS:

1. `check.sh` (the startup time is reported, not enforced, on shared runners);
2. the install scripts, with macOS's own `/bin/bash` 3.2 there;
3. the installed shells, as a user gets them: `zsh -i .github/smoke.zsh` and
   `bash -i .github/smoke.bash`, with aliases, prompt, directory jump and a real
   plugin install;
4. on macOS, `bashrc` stopping cleanly under bash 3.2.

A feature the self-check can't cover gets a line in the smoke tests.

## Website

The site, <https://fmatsos.github.io/shellkit/>, lives on the `gh-pages` branch: the
landing page, the templates and `build.py`. Its documentation pages are these `docs/`,
rebuilt by `.github/workflows/pages.yml` at every push to `main` that touches them
(or by hand: *Actions → pages → Run workflow*). `build.py` renders them with GitHub's
Markdown API and fails on a broken link between pages or to an anchor, so a doc that
only works on github.com shows up there.

To change the site itself, check out `gh-pages`, edit `src/` and run
`python3 build.py <path to main's docs/>` before committing: see its `README.md`.

## Releasing

A release is a tag `vX.Y.Z`:

```bash
git tag -a v1.2.0 -m v1.2.0
git push origin v1.2.0
```

`.github/workflows/release.yml` runs the full CI on the tag. If it passes, it:

1. creates the GitHub release, with notes generated from the commits since the
   previous tag. A tag with a suffix (`v2.0.0-rc.1`) becomes a pre-release;
2. for a stable tag, moves the `release` branch to it, fast-forward only.

Clones follow the `release` branch, never raw tags: `shkit update`, and a background
job at startup at most once a day (see [Updating](installation.md#updating)).
**Only a tag that passed CI ever reaches a clone.** So:

- follow [semver](https://semver.org): a breaking change of settings or of the
  block contract is a major version;
- never push to `release` by hand, and never rewrite it. Clones refuse a
  rewritten release branch;
- never move or delete a published tag;
- a failed release is fixed by a new tag (`v1.2.1`). There is nothing to roll back.

## Agent skills

`.claude/skills/` holds instructions for coding agents working in this repository:

| Skill | For |
|-------|-----|
| `config-commit` | checks, then commit in the repository's style (`check.sh`) |
| `shell-config` | options, aliases, completion, install scripts, where a setting belongs |
| `prompt-theme` | the prompt engine: blocks, jobs, colors, layers, `shkit` |
| `prompt-plugin` | writing a plugin |
| `website` | the site on `gh-pages`: pages, build, accessibility and performance checks, publishing |
| `visuals` | the mascot, illustrations, sprite sheets and screenshots, generated with Codex (`sprite-check.py`) |
