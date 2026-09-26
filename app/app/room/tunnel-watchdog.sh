#!/usr/bin/env bash
# Recover Cloudflare's 1033 for either public hostname while the login gateway is healthy.
set -euo pipefail
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
service=desk-v2-tunnel.service
local_url=http://127.0.0.1:6081/
failures=0
last_restart=0
cycles=0
probe(){ curl --silent --output /dev/null --max-time 3 --write-out '%{http_code}' "$1" 2>/dev/null || true; }
local_ok(){
  [[ $(curl --silent --output /dev/null --max-time 2 --write-out '%{http_code}' \
    -H 'Host: desk.novamail.store' -H 'X-Forwarded-Proto: https' "$local_url" 2>/dev/null || true) == 401 ]]
}
public_failure(){
  desk_code=$(probe 'https://desk.novamail.store/')
  room_code=$(probe 'https://room.novamail.store/')
  # Either route being broken is an outage; edge responses can differ between probes.
  [[ "$desk_code" == 530 || "$room_code" == 530 ]]
}
while true; do
  sleep "${WATCHDOG_PROBE_INTERVAL:-5}"
  ((cycles+=1))
  if ! public_failure || ! local_ok; then
    if ((failures>0)); then printf 'Public probe recovered or local gateway unhealthy: desk=%s room=%s consecutive=%d\n' "$desk_code" "$room_code" "$failures"; fi
    failures=0
    if ((cycles>=${WATCHDOG_MAX_CYCLES:-2147483647})); then break; fi
    continue
  fi
  ((failures+=1))
  if ((failures==1)); then printf 'Public failure observed: desk=%s room=%s, localhost healthy.\n' "$desk_code" "$room_code"; fi
  if ((failures>=3)); then
    now=$(date +%s)
    if ((now-last_restart>=120)) && systemctl --user is-active --quiet "$service" && local_ok && public_failure; then
      printf 'Public 530 persisted across three probes: desk=%s room=%s, localhost healthy. Restarting connector at %s.\n' "$desk_code" "$room_code" "$(date -Is)"
      last_restart=$now; failures=0
      systemctl --user restart "$service" || printf 'Tunnel restart failed; systemd will retry.\n' >&2
    fi
  fi
  if ((cycles>=${WATCHDOG_MAX_CYCLES:-2147483647})); then break; fi
done
