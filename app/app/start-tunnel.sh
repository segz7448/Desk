#!/usr/bin/env bash
# Operator must provision a fresh token privately; no token is stored in this script.
set -euo pipefail
if [ -r /home/sandbox/desk/state/tunnel.token ]; then
  exec /home/sandbox/desk/cloudflared tunnel --protocol http2 run --token-file /home/sandbox/desk/state/tunnel.token
fi
printf 'Desk tunnel token missing from private state; original tunnel may still be running.\n' >&2
exit 78
