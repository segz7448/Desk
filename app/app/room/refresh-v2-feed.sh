#!/usr/bin/env bash
set -euo pipefail
cd /home/sandbox/Desk-v2
while true; do
  python3 app/app/render-feed.py /home/sandbox/desk/view-only/status.json state/feed/status.json >/tmp/desk-live-feed.log 2>&1 || true
  sleep 60
done
