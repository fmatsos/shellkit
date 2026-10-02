# AGENTS.md

shellkit: personal shell configuration (zsh, bash, prompt, scripts), driven by the
`shkit` command. The repo is public: every commit is.

## Rule #1 — never commit or push a secret

No token, API key, password, private key, cookie or credential ever goes into
this repo — not in a file, not in a commit message, not in an example.
**Always use substitution**: the repo references a variable, the value lives
outside the repo.

- Secrets live in `~/.config/shkit/secrets.sh` (`chmod 600`, sourced last by `zshrc` and `bashrc`).
  Code in the repo only uses the variable: `"$SLACKCLI_XOXC_TOKEN"`, never its
  value.
- Everything outside the repo sits in one directory, `~/.config/shkit/` (chmod 700).
- Machine-specific settings (hosts, extra `PATH`s, env flags) live in
  `~/.config/shkit/settings.sh`, aliases and functions for one machine (work tools, client
  paths) in `~/.config/shkit/aliases.sh`, the zsh prompt's look in `~/.config/shkit/theme.zsh`, both outside the repo.
- Docs and examples use placeholders: `export FOO_TOKEN=<token>`.
- A new secret is added to `~/.config/shkit/secrets.sh`, never to a tracked file. Don't
  print secret values in a terminal or a log either.
- Before every commit, scan what is staged; commit only if both checks are clean:

  ```bash
  # 1. exact values from ~/.config/shkit/secrets.sh (values are never printed)
  while IFS= read -r v; do [[ ${#v} -ge 8 ]] && git grep -qF --cached -- "$v" && echo "SECRET FOUND"; done \
    < <(sed -nE "s/^export [A-Z_]+=['\"]?([^'\"]*)['\"]?$/\1/p" ~/.config/shkit/secrets.sh)
  # 2. common token shapes (exit code 1 = nothing found)
  git grep -nE --cached 'xox[abpcdr]-[0-9A-Za-z-]{10,}|sk-[A-Za-z0-9]{20,}|gh[pousr]_[A-Za-z0-9]{20,}|glpat-[A-Za-z0-9_-]{15,}|BEGIN [A-Z ]*PRIVATE KEY|AKIA[0-9A-Z]{16}'
  ```

- `.claude/skills/config-commit/check.sh` runs both scans, plus syntax, the prompt
  self-check and the startup budget.
- CI (`.github/workflows/check.yml`), Linux and macOS, at every push: `check.sh` (startup
  budget reported, not enforced there), the install scripts (macOS: `/bin/bash` 3.2), then
  the installed shells (`.github/smoke.zsh`, `.github/smoke.bash`). A new feature gets its
  line there when the self-check can't cover it.
- If a secret was committed: stop, don't push, tell the user — it must be
  rotated, rewriting history is not enough once pushed.

## Rule #2 — everything runs on Linux and macOS

Every change must work fully on both, with no Linux-only or macOS-only feature.
When no portable way exists, give each OS its own path and keep a fallback.
Tested on one OS only: say so, and list what to check on the other.

- No GNU-only flag: `stat -c`, `date +%N`, `sed -i`, `xargs -r`, `timeout` (use
  `_prompt_timeout`). No `/proc` without a fallback.
- Prefer a zsh builtin (`zstat`, `$EPOCHREALTIME`, `:A`) to an `$OSTYPE` branch:
  Linux then runs the same code as the Mac, and the checks cover it.
- A fallback that only macOS takes gets a check that forces it on Linux (see
  `prompt.check.zsh`: `unhash timeout`, `_prompt_proc`).
- Paths outside the repo: try Linux, Homebrew (`/opt/homebrew`, `/usr/local`) and
  Apple (`/Library/Developer/CommandLineTools`) in turn.
- Install scripts run on macOS's bash 3.2 (no `declare -A`, no `${x,,}`);
  `bashrc` needs bash 5.1+.

## Layout

| Path | Role |
|------|------|
| `zsh/zshrc`, `zsh/zshenv` | default shell, symlinked by `zsh/install.sh`; `zsh/try.sh` runs them without installing; `prompt.zsh` alone = prompt only |
| `zsh/prompt.zsh` | the prompt (async redraw); self-check: `zsh zsh/prompt.check.zsh` |
| `zsh/plugin/` | prompt plugins: `schema.json` (the `plugin.json` a plugin repository must follow), `validate.jq`, `example/` |
| `zsh/shkit.zsh` | `shkit`: edits the theme / project settings files for the user, manages plugins, updates shellkit (also in the background at startup), checks the setup (`doctor`) |
| `shell/install-local.sh` | creates `~/.config/shkit/` (the files outside the repo), migrates the old `~/.config/shell/` and `~/.*.local` |
| `shell/aliases.sh` | aliases and functions shared by bash and zsh — keep it portable |
| `bash/` | fallback bash config (`bashrc` with a minimal prompt, `completion.sh`) |
| `bin/` | scripts, installed in `~/.bin` |
| `docs/` | user documentation (GFM), linked from `README.md` |
| `.github/` | `workflows/check.yml` (CI), `workflows/release.yml` (tag `vX.Y.Z` = release), `workflows/pages.yml` (`docs/` → the website on `gh-pages`), `smoke.*`, `bench/` (the README's speed table), `demo/` (the prompt GIFs, VHS in Docker) |
| `.claude/skills/` | agent skills: `config-commit` (checks + commit, `check.sh`), `prompt-theme`, `prompt-plugin` (writing a plugin), `shell-config`, `website` (the `gh-pages` site), `visuals` (images and sprites, made with Codex) |

## Conventions

- Plain zsh / bash, no framework (no Oh My Zsh / Oh My Bash).
- `noclobber` is on in both shells: overwrite an existing file with `>|`, not `>`.
- The prompt's synchronous path stays local and fast (< 50 ms on a large
  repo); anything networked goes through its background cache.
- Prompt features live in `zsh/prompt.zsh` only; the bash prompt stays minimal
  on purpose. Run `zsh zsh/prompt.check.zsh` after changing it.
- A new prompt segment = a `_prompt_seg_<name>` function appending to `segs`,
  plus its `{name}` in the `SHKIT_FORMAT` (or `SHKIT_RIGHT_FORMAT`) default. Colors are roles
  (`SHKIT_COLOR_*`) and icons are `SHKIT_ICON_*` (used as `$_i_<name>`),
  never literals in the segment. A block for this machine only goes in
  `~/.config/shkit/prompt.d/<name>.zsh` instead (loaded after the built-ins, same contract).
- Plugins (`~/.config/shkit/plugins/`, `shkit plugin`) are remote code in every
  shell: never fetch or update one without the user asking, and show what it brings.
- shellkit updates itself from its own releases only (the user's choice): the `release`
  branch, which `release.yml` fast-forwards to a `vX.Y.Z` tag once CI passed on it.
  Clones fast-forward to it, never over local changes, commits or another branch. So
  `release` is never pushed by hand or rewritten, a published tag is never moved, and a
  breaking change is a major version.
- A change users see (a command, a setting, a block, a behaviour) updates `docs/` in
  the same commit; the README stays an overview.
