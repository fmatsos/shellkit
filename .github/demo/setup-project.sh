#!/usr/bin/env bash
set -euo pipefail

export HOME=/home/dev
repo=$HOME/code/shop
remote=$HOME/remotes/gitlab.example.com/shop.git
seed=$HOME/.shop-seed
mkdir -p "$HOME/code" "$HOME/remotes/gitlab.example.com"
rm -rf "$repo" "$remote" "$seed"

/usr/bin/git init --bare "$remote" >/dev/null
/usr/bin/git init -b main "$seed" >/dev/null
cd "$seed"
/usr/bin/git config user.name 'Demo Developer'
/usr/bin/git config user.email 'demo@example.test'
printf '# Shop\n\nA deterministic demo repository.\n' > README.md
printf 'item,price\ncoffee,4\n' > catalog.csv
commit_at() {
  local date=$1 message=$2
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    /usr/bin/git add -A &&
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    /usr/bin/git commit -m "$message" >/dev/null
}
commit_at '2026-01-01T10:00:00+00:00' 'Create shop project'
/usr/bin/git remote add origin "$remote"
/usr/bin/git push -u origin main >/dev/null
/usr/bin/git --git-dir="$remote" symbolic-ref HEAD refs/heads/main

/usr/bin/git switch -c feature/SHOP-482-checkout >/dev/null
printf '\nCheckout flow: draft\n' >> README.md
commit_at '2026-01-02T10:00:00+00:00' 'Start checkout flow'
/usr/bin/git push -u origin feature/SHOP-482-checkout >/dev/null

/usr/bin/git switch main >/dev/null
printf 'main-version\n' > conflict.txt
commit_at '2026-01-04T10:00:00+00:00' 'Change file on main'
/usr/bin/git push origin main >/dev/null

# Clone before creating the three remote-only commits. The clone gets exactly
# one local commit of its own, then the remote feature branch advances by three.
/usr/bin/git clone "$remote" "$repo" >/dev/null
cd "$repo"
/usr/bin/git config user.name 'Demo Developer'
/usr/bin/git config user.email 'demo@example.test'
/usr/bin/git switch feature/SHOP-482-checkout >/dev/null
printf '\nA local checkout note.\n' >> README.md
GIT_AUTHOR_DATE='2026-01-05T10:00:00+00:00' GIT_COMMITTER_DATE='2026-01-05T10:00:00+00:00' \
  /usr/bin/git add README.md
GIT_AUTHOR_DATE='2026-01-05T10:00:00+00:00' GIT_COMMITTER_DATE='2026-01-05T10:00:00+00:00' \
  /usr/bin/git commit -m 'Add local checkout note' >/dev/null

/usr/bin/git clone "$remote" "$seed-update" >/dev/null 2>&1
cd "$seed-update"
/usr/bin/git config user.name 'Demo Developer'
/usr/bin/git config user.email 'demo@example.test'
/usr/bin/git switch feature/SHOP-482-checkout >/dev/null
for spec in \
  '2026-01-06T10:00:00+00:00|Add checkout validation' \
  '2026-01-07T10:00:00+00:00|Document payment step' \
  '2026-01-08T10:00:00+00:00|Polish checkout summary'; do
  date=${spec%%|*}
  message=${spec#*|}
  printf '%s\n' "$message" >> remote-checkout.log
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" /usr/bin/git add remote-checkout.log
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" /usr/bin/git commit -m "$message" >/dev/null
done
/usr/bin/git push origin feature/SHOP-482-checkout >/dev/null
rm -rf "$seed" "$HOME/seed-update"

# A local-only branch whose single commit conflicts when replayed onto main.
cd "$repo"
/usr/bin/git switch -c rebase-conflict HEAD~1 >/dev/null
printf 'rebase-conflict\n' > conflict.txt
GIT_AUTHOR_DATE='2026-01-09T10:00:00+00:00' GIT_COMMITTER_DATE='2026-01-09T10:00:00+00:00' \
  /usr/bin/git add conflict.txt
GIT_AUTHOR_DATE='2026-01-09T10:00:00+00:00' GIT_COMMITTER_DATE='2026-01-09T10:00:00+00:00' \
  /usr/bin/git commit -m 'Add conflicting local change' >/dev/null
/usr/bin/git switch feature/SHOP-482-checkout >/dev/null

# Two tracked files with stable added/removed counts for the async scene.
cd "$repo"
printf '\nLocal edit for the diff scene.\n' >> README.md
printf 'item,price\ncoffee,5\ntea,3\n' > catalog.csv
