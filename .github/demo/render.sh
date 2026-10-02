#!/usr/bin/env bash
# The prompt GIFs of the README and docs/ (docs/assets/demo-*.gif): the real prompt,
# recorded by VHS in Docker. Renders the committed HEAD (it is cloned, not copied).
#   .github/demo/render.sh [TAPE NAME]...   (default: every tape)
set -euo pipefail

script_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
shellkit_repo=$(cd -- "$script_dir/../.." && pwd)
out_dir=$shellkit_repo/docs/assets
image_name=shellkit-prompt-recorder
if [[ ! -e $shellkit_repo/.git ]]; then
  echo "not a shellkit checkout: $shellkit_repo" >&2
  exit 1
fi

docker build --build-arg UID="$(id -u)" -t "$image_name" -f "$script_dir/Dockerfile" "$script_dir"
names=("$@")
[[ ${#names[@]} -gt 0 ]] || for tape in "$script_dir"/tapes/*.tape; do name=${tape##*/}; names+=("${name%.tape}"); done
for name in "${names[@]}"; do
  docker run --rm \
    -v "$shellkit_repo:/shellkit:ro" \
    -v "$script_dir:/demo:ro" \
    -v "$out_dir:/out" \
    "$image_name" "/demo/tapes/$name.tape"
done
