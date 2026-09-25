#!/usr/bin/env bash
# Run inside Desk's isolated guest. This never uses host identity or credentials.
set -u
ROOT=/home/deskguest/workspace
for dir in "$ROOT"/*; do
  [ -d "$dir/.git" ] || continue
  [ ! -L "$dir" ] || continue
  url=$(git -C "$dir" remote get-url origin 2>/dev/null) || continue
  name=${dir##*/}
  [ "$url" = "https://github.com/segz7448/$name.git" ] || continue
  if [ -z "$(git -C "$dir" status --porcelain 2>/dev/null)" ]; then
    timeout 90 git -C "$dir" -c credential.helper= -c core.askPass=/bin/false pull --ff-only -q </dev/null 2>&1 || true
  fi
done
