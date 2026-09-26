#!/usr/bin/env bash
set -euo pipefail
while true; do
  /home/sandbox/desk/room/workspace-refresh-live.sh >>/tmp/desk-workspace-refresh-supervisor.log 2>&1 || true
  sleep 10
done
