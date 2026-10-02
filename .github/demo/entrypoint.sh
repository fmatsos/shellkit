#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: entrypoint.sh TAPE" >&2
  exit 2
fi

tape=$1
[[ -r $tape ]] || { echo "tape not readable: $tape" >&2; exit 2; }
chown -R dev:dev /home/dev
runuser -u dev -- /usr/bin/git config --global --add safe.directory '*'
runuser -u dev -- /usr/bin/git config --global advice.mergeConflict false
runuser -u dev -- /usr/bin/git clone -q /shellkit /home/dev/shellkit
runuser -u dev -- /bin/bash /home/dev/shellkit/zsh/install.sh
mkdir -p /home/dev/.config/shkit
cat > /home/dev/.config/shkit/settings.sh <<'SETTINGS'
export SHKIT_AUTO_UPDATE=false
export SHKIT_NOTIFY=false
SETTINGS
chown dev:dev /home/dev/.config/shkit/settings.sh
chmod 600 /home/dev/.config/shkit/settings.sh
runuser -u dev -- /demo/setup-project.sh


exec runuser -u dev -- env \
  PATH="/demo/stubs:/home/dev/.local/bin:/usr/local/bin:/usr/bin:/bin" \
  HOME=/home/dev \
  vhs "$tape"
