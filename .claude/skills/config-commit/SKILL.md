---
name: config-commit
description: Commit and push changes to this config repo safely — runs the pre-commit checks (secret scan, shell syntax, prompt self-check, startup budget), writes the commit in the repo's style, and only pushes on the user's OK. Use whenever a change to this repo is ready to commit, push or merge.
---

# Commit this config repo

Rule #1 of `AGENTS.md` comes first: **no secret ever reaches git**. The repo only
references variables (`"$SLACKCLI_XOXC_TOKEN"`); values live in `~/.config/shkit/secrets.sh`.
Never print a value of `~/.config/shkit/secrets.sh`, not even to "check" it.

## Steps

1. Stage: `git -C <repo> add -A`, then `git -C <repo> status -s`. Read the list:
   nothing from `$HOME` (`*.local`, `.env*` are ignored, keep it that way).
2. Run the checks, after staging (the secret scan reads the index):

   ```bash
   .claude/skills/config-commit/check.sh
   ```

   Exit 1 = don't commit. A secret found: stop, unstage, tell the user. If it was
   already pushed, it must be **rotated**, rewriting history is not enough.
3. Commit, message in the repo's style (see `git log --format=%s`):
   - subject: third-person verb, what the change does — "Makes the zsh prompt
     icons themeable", "Keeps the bash prompt minimal, …";
   - body: why, in a few lines — the constraint or the problem, not a file list;
   - end with the attribution lines the session gives.
4. Push **only when the user says so** (`git -C <repo> push origin main`), then
   confirm `## main...origin/main`.

## Conventions

- Git through `git -C <path>`: a hook blocks `cd` before git commands.
- Small changes go straight to `main`. A migration (e.g. bash → zsh) gets a
  branch, merged into `main` with a merge commit, then the branch is deleted
  locally and on the remote — each step on the user's go.
- Deleting tracked files: propose the `git rm` to the user if the permission
  classifier refuses it; the files stay in history.
- Files outside the repo the user asked not to touch: `~/.bash_aliases`,
  `~/.bashrc.pre-config` (old config, contains plaintext secrets, chmod 600).
