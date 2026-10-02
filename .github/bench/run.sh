#!/usr/bin/env bash
# The README's speed table: zsh-bench (github.com/romkatv/zsh-bench), in Docker only,
# shellkit (full and prompt only) next to other prompts and frameworks. Two runs.
#   .github/bench/run.sh [DIR]   (DIR: a scratch directory, default a temporary one)
set -eu
repo=$(cd "$(dirname "$0")/../.." && pwd)
d=${1:-$(mktemp -d)}
[ -d "$d/zsh-bench" ] || git clone -q https://github.com/romkatv/zsh-bench "$d/zsh-bench"
git -C "$d/zsh-bench" checkout -q 28b1b1b
# its image is ubuntu:22.04 (zsh 5.8, older than CI's 5.9), and it reads /proc/1/cpuset
# that cgroup v2 hosts no longer have
sed -i.bak -e 's|img=ubuntu:22.04|img=ubuntu:24.04|' -e "s|'cpuset=\"\$(cat /proc/1/cpuset)\"'|'cpuset=\$(hostname)'|" \
  "$d/zsh-bench/zsh-bench"
c=$d/zsh-bench/configs
for n in shellkit shellkit-prompt pure; do
  rm -rf "${c:?}/$n"; mkdir -p "$c/$n/skel"
  printf '#!/usr/bin/env zsh\nemulate -L zsh -o err_return\ncp -r -- ${ZSH_SCRIPT:h}/skel/*(D) ~/\n' >"$c/$n/setup"
  chmod +x "$c/$n/setup"
done
for n in shellkit shellkit-prompt; do
  mkdir -p "$c/$n/skel/shellkit" && git -C "$repo" archive HEAD | tar -x -C "$c/$n/skel/shellkit"
done
printf 'setopt no_global_rcs\nsource ~/shellkit/zsh/zshenv\nexport SHKIT_AUTO_UPDATE=false\n' >"$c/shellkit/skel/.zshenv"
printf 'source ~/shellkit/zsh/zshrc\n' >"$c/shellkit/skel/.zshrc"
printf 'setopt no_global_rcs\nexport SHKIT_AUTO_UPDATE=false\n' >"$c/shellkit-prompt/skel/.zshenv"
printf 'source ~/shellkit/zsh/prompt.zsh\n' >"$c/shellkit-prompt/skel/.zshrc"
printf 'git clone -q --depth=1 https://github.com/sindresorhus/pure.git ~/.zsh/pure\n' >>"$c/pure/setup"
printf 'setopt no_global_rcs\n' >"$c/pure/skel/.zshenv"
printf 'fpath+=(~/.zsh/pure)\nautoload -U promptinit; promptinit\nprompt pure\n' >"$c/pure/skel/.zshrc"
for run in 1 2; do
  (cd "$d/zsh-bench" && ./zsh-bench --isolation docker --iters 32 \
    compsys git-branch shellkit-prompt starship pure powerlevel10k shellkit ohmyzsh </dev/null) | tee "$d/run$run.txt"
done
