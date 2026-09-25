#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT=$(CDPATH= cd -- "$ROOT/../.." && pwd)
INPUT=${DESK_FEED_INPUT:-"$ROOT/status.json"}
OUTPUT="$PROJECT/state/feed/status.json"
mkdir -p "$PROJECT/state/feed"
while true; do
  python3 "$ROOT/render-feed.py" "$INPUT" "$OUTPUT"
  sleep 60
done
