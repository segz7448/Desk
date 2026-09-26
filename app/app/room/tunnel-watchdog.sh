#!/usr/bin/env bash
# Detect a sustained public 1033 despite a healthy local gateway; connector metrics can lie.
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
service=desk-v2-tunnel.service
local_url=http://127.0.0.1:6081/
failures=0
last_restart=0
probe(){ curl --silent --output /dev/null --max-time 3 --write-out '%{http_code}' "$1" 2>/dev/null || true; }
local_ok(){
  [[ $(curl --silent --output /dev/null --max-time 2 --write-out '%{http_code}' \
    -H 'Host: desk.novamail.store' -H 'X-Forwarded-Proto: https' "$local_url" 2>/dev/null || true) == 401 ]]
}
public_1033(){
  local desk_code room_code
  desk_code=$(probe 'https://desk.novamail.store/')
  room_code=$(probe 'https://room.novamail.store/')
  [[ "$desk_code" == 530 && "$room_code" == 530 ]]
}
while true; do
  sleep 5
  if ! public_1033 || ! local_ok; then failures=0; continue; fi
  ((failures+=1))
  # One poor probe is not a reason to reset a usable websocket. Confirm sustained 1033.
  if ((failures<3)); then continue; fi
  now=$(date +%s)
  if ((now-last_restart<120)); then continue; fi
  if ! systemctl --user is-active --quiet "$service" || ! local_ok || ! public_1033; then
    failures=0; continue
  fi
  printf 'Both public Desk hosts returned 1033 in three probes, localhost healthy. Restarting connector once at %s.\n' "$(date -Is)"
  last_restart=$now; failures=0
  systemctl --user restart "$service" || printf 'Tunnel restart failed; systemd will retry.\n' >&2
done
