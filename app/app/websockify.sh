#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# Serve noVNC from the installed package alongside the application page.
mkdir -p "$ROOT/public"
ln -sfn ../../../node_modules/@novnc/novnc "$ROOT/public/novnc"
ln -sfn ../index.html "$ROOT/public/index.html"
exec /usr/bin/python3 -m websockify --web="$ROOT/public" --unix-target="$ROOT/bridge/vnc.sock" "127.0.0.1:${DESK_WEBSOCKIFY_PORT:-6080}"
