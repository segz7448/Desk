#!/usr/bin/env bash
# Userspace tunnel watchdog when systemctl --user is unavailable. Requires a private
# state/ops/tunnel.pid written by the connector launcher; no token is logged.
set -euo pipefail
root=$(cd -- "$(dirname -- "$0")/../../.." && pwd)
state="$root/state/ops"
mkdir -p "$state"; chmod 700 "$state"
failures=0; last_restart=0; cycles=0
probe(){ curl -sS --max-time 3 -o /dev/null -w '%{http_code}' "$1" 2>/dev/null || true; }
local_ok(){
 local code
 code=$(curl -sS --max-time 2 -o /dev/null -w '%{http_code}' \
  -H 'Host: desk.novamail.store' -H 'X-Forwarded-Proto: https' http://127.0.0.1:6081/ 2>/dev/null || true)
 if [[ $code == 401 ]];then return 0;fi
 # Bootstrap has no public root and never serves the desktop. Do not probe its
 # one-use secret path: that could exhaust its request limit.
 if [[ $code == 404 && -f "$state/bootstrap.pid" ]];then
  local pid;pid=$(cat "$state/bootstrap.pid" 2>/dev/null || true)
  [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null &&
    [[ $(sqlite3 "$root/state/auth.sqlite" 'SELECT count(*) FROM accounts;' 2>/dev/null || true) == 0 ]]
  return
 fi
 return 1
}
public_failure(){
 desk_code=$(probe https://desk.novamail.store/)
 room_code=$(probe https://room.novamail.store/)
 [[ $desk_code == 530 || $desk_code == 502 || $room_code == 530 || $room_code == 502 ]]
}
while true;do
 sleep "${WATCHDOG_PROBE_INTERVAL:-15}";((cycles+=1))
 if ! public_failure || ! local_ok;then
  if ((failures));then printf 'Public probe recovered or local unhealthy: desk=%s room=%s consecutive=%d\n' "$desk_code" "$room_code" "$failures";fi
  failures=0
 elif ((++failures>=1));then
  if ((failures==1));then printf 'Public failure: desk=%s room=%s local healthy\n' "$desk_code" "$room_code";fi
  now=$(date +%s)
  if ((failures>=3 && now-last_restart>=120)) && local_ok && public_failure;then
   pid=$(cat "$state/tunnel.pid" 2>/dev/null || true)
   if [[ $pid =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null &&
      tr '\0' ' ' < "/proc/$pid/cmdline" | grep -q '/cloudflared tunnel';then
    printf 'Sustained public failure: desk=%s room=%s local healthy; restarting connector at %s\n' "$desk_code" "$room_code" "$(date -Is)"
    last_restart=$now;failures=0;kill "$pid" || true;sleep 2
    nohup "${DESK_CLOUDFLARED:-/home/sandbox/cloudflared}" tunnel --protocol http2 run --token-file "$root/state/tunnel.token" >>"$root/state/ops/cloudflared.log" 2>&1 </dev/null & echo $! > "$state/tunnel.pid"
   fi
  fi
 fi
 if ((cycles>=${WATCHDOG_MAX_CYCLES:-2147483647}));then break;fi
done
