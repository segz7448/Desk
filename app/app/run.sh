#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"
set -a; source ./.env; set +a
if [ ! -f "${DESK_DB_PATH:-state/auth.sqlite}" ]; then echo 'Run ./app/app/setup.sh first' >&2; exit 1; fi
mkdir -p state app/app/bridge
pids=()
cleanup(){ trap - EXIT INT TERM; for pid in "${pids[@]}"; do kill -- "-$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true; done; wait || true; }
trap cleanup EXIT
trap "exit 130" INT
trap "exit 143" TERM
rm -f app/app/bridge/vnc.sock
setsid sh ./app/app/isolated-display.sh & pids+=($!)
for i in $(seq 1 30); do [ -S app/app/bridge/vnc.sock ] && break; sleep 1; done
[ -S app/app/bridge/vnc.sock ] || { echo 'VNC bridge did not start' >&2; exit 1; }
setsid sh ./app/app/websockify.sh & pids+=($!)
setsid node app/app/gateway.cjs & pids+=($!)
if [ -n "${CLOUDFLARE_TUNNEL_TOKEN:-}" ]; then
  setsid cloudflared tunnel run --token "$CLOUDFLARE_TUNNEL_TOKEN" & pids+=($!)
fi
printf 'Desk running locally. Public hostname: %s\n' "${DESK_HOSTNAMES:-not configured}"
wait -n "${pids[@]}"
