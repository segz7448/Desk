#!/usr/bin/env bash
# Fail-safe recovery for sustained tunnel outage, not for brief network flaps.
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
service=desk-v2-tunnel.service
metrics=http://127.0.0.1:20241/metrics
local_url=http://127.0.0.1:6081/
failures=0
last_restart=0
while true; do
  sleep 15
  # No public request at all unless the connector itself reports zero edge connections.
  count=$(curl --silent --show-error --max-time 2 "$metrics" 2>/dev/null | awk '$1=="cloudflared_tunnel_ha_connections" {print $2; exit}') || count=''
  if [[ "$count" != 0 ]]; then failures=0; continue; fi
  local_code=$(curl --silent --output /dev/null --max-time 2 --write-out '%{http_code}' \
    -H 'Host: desk.novamail.store' -H 'X-Forwarded-Proto: https' "$local_url" 2>/dev/null) || local_code=''
  if [[ "$local_code" != 401 ]]; then failures=0; continue; fi
  desk_code=$(curl --silent --output /dev/null --max-time 4 --write-out '%{http_code}' 'https://desk.novamail.store/' 2>/dev/null) || desk_code=''
  room_code=$(curl --silent --output /dev/null --max-time 4 --write-out '%{http_code}' 'https://room.novamail.store/' 2>/dev/null) || room_code=''
  if [[ "$desk_code" != 530 || "$room_code" != 530 ]]; then failures=0; continue; fi
  ((failures+=1))
  if ((failures<2)); then continue; fi
  now=$(date +%s)
  if ((now-last_restart<180)); then continue; fi
  # Confirm again immediately before restart, since a self-healing connector can reconnect in seconds.
  count=$(curl --silent --show-error --max-time 2 "$metrics" 2>/dev/null | awk '$1=="cloudflared_tunnel_ha_connections" {print $2; exit}') || count=''
  if [[ "$count" != 0 ]]; then failures=0; continue; fi
  if ! systemctl --user is-active --quiet "$service"; then failures=0; continue; fi
  printf 'Sustained zero-edge tunnel and both public hosts at 530, localhost healthy; restarting connector once.\n'
  last_restart=$now; failures=0
  systemctl --user restart "$service" || printf 'Tunnel restart failed; systemd will retry.\n' >&2
done
