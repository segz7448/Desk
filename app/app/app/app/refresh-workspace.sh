#!/usr/bin/env bash
# Host-side public-source mirror. Only explicit public repositories; never credentials.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
WORKSPACE="$ROOT/state/home/workspace"
LIST="$ROOT/state/public-repos.txt"
mkdir -p "$WORKSPACE"
[ -f "$LIST" ] || { echo 'Missing public repo allowlist' >&2; exit 1; }
while IFS= read -r url; do
  [[ "$url" =~ ^https://github\.com/segz7448/[A-Za-z0-9._-]+$ ]] || continue
  name=${url##*/}
  target="$WORKSPACE/$name"
  if [ -e "$target" ] && [ ! -d "$target/.git" ]; then continue; fi
  # Refuse a symlink or redirection to any other host location.
  [ ! -L "$target" ] || continue
  if [ ! -d "$target/.git" ]; then
    tmp=$(mktemp -d "$WORKSPACE/.repo-XXXXXXXX")
    if timeout 60 git -c credential.helper= -c core.askPass=/bin/false clone --depth 1 "$url.git" "$tmp" </dev/null >/dev/null 2>&1 && git -C "$tmp" rev-parse --verify HEAD >/dev/null 2>&1; then
      mv -T "$tmp" "$target"
      echo "Added $name"
    else rm -rf -- "$tmp"; echo "Skipped unavailable/empty $name"; fi
  else echo "Already present $name; refresh must run inside guest, not as host against guest-editable files"; fi
done < "$LIST"
