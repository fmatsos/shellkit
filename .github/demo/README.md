# shellkit prompt recordings

This folder builds four VHS recordings of the **real** shellkit zsh prompt. At
runtime, the repository is mounted read-only at `/shellkit`; the container
clones it to `/home/dev/shellkit`, runs its installer, and makes a deterministic
local GitLab-shaped project under `/home/dev/code/shop`.

## Files

- `Dockerfile` starts from the VHS image, installs zsh/git/jq/perl and Symbols
  Nerd Font Mono, and creates the unprivileged `dev` user.
- `entrypoint.sh` clones the mounted shellkit checkout into a writable home,
  runs its installer, applies demo-only settings and starts VHS as `dev`.
- `setup-project.sh` creates the local bare GitLab-like origin, reproducible
  commit history, remote-only commits, local modifications and a prepared
  conflicting-rebase branch.
- `stubs/glab` simulates only the GitLab service responses used by the prompt;
  `stubs/git` adds delay to background fetches and delegates every Git command
  to `/usr/bin/git`.
- `tapes/*.tape` define the four scenes and their VHS capture settings.
- `render.sh` builds the image, then runs one fresh container for each tape.

## Run

```sh
.github/demo/render.sh          # every scene
.github/demo/render.sh git      # one
```

Docker must be available. It records the committed `HEAD` of this checkout (commit
first) into `docs/assets/demo-<scene>.gif`, used by the README and `docs/`.

## Hard rule

Every prompt frame comes from shellkit's actual `zsh/prompt.zsh`, running in an
interactive real zsh inside VHS. No prompt text, colors, or symbols are drawn,
substituted, or edited after capture. Only GitLab's network-facing `glab`
responses are simulated; the Git wrapper runs the system Git binary.
