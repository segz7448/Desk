#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
INPUT=${DESK_FEED_INPUT:-"$ROOT/status.json"}
while true; do
  python3 "$ROOT/render-feed.py" "$INPUT" "$ROOT/status.json"
  sleep 60
done
