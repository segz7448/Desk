#!/usr/bin/env bash
set -euo pipefail
cd /home/sandbox/Desk-v2
mkdir -p state/feed app/app/bridge
python3 app/app/render-feed.py /home/sandbox/desk/view-only/status.json state/feed/status.json >/tmp/desk-live-feed.log
rm -f app/app/bridge/egress.sock
python3 app/app/egress-proxy.py app/app/bridge/egress.sock >/tmp/desk-live-egress.log 2>&1 & proxy=$!
cleanup(){ kill "$proxy" 2>/dev/null || true; wait "$proxy" 2>/dev/null || true; }
trap cleanup EXIT INT TERM
for i in $(seq 1 30); do [ -S app/app/bridge/egress.sock ] && break; sleep .1; done
bash app/app/isolated-display.sh
