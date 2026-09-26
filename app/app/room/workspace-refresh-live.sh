#!/usr/bin/env bash
set -euo pipefail
cd /home/sandbox/Desk-v2
args=(--die-with-parent --unshare-all --hostname desk-remote-pc
  --ro-bind /usr /usr --ro-bind /etc/ssl/certs /etc/ssl/certs
  --proc /proc --dev /dev --tmpfs /tmp --tmpfs /home --tmpfs /run --tmpfs /var --dir /etc
  --bind /home/sandbox/Desk-v2/state/home /home/deskguest
  --ro-bind /home/sandbox/Desk-v2/app/app /home/app
  --bind /home/sandbox/Desk-v2/app/app/bridge /bridge
  --ro-bind /home/sandbox/Desk-v2/state/etc/passwd /etc/passwd
  --ro-bind /home/sandbox/Desk-v2/state/etc/group /etc/group
  --ro-bind /home/sandbox/Desk-v2/state/etc/hosts /etc/hosts
  --ro-bind /home/sandbox/Desk-v2/state/etc/resolv.conf /etc/resolv.conf
  --ro-bind /home/sandbox/Desk-v2/state/etc/hostname /etc/hostname
  --ro-bind /home/sandbox/Desk-v2/state/etc/machine-id /etc/machine-id
  --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64
  --setenv HOME /home/deskguest --setenv USER deskguest --setenv LOGNAME deskguest
  --setenv PATH /usr/bin:/bin --setenv http_proxy http://127.0.0.1:3128 --setenv https_proxy http://127.0.0.1:3128
  --setenv no_proxy localhost,127.0.0.1 --setenv GIT_CONFIG_NOSYSTEM 1)
exec bwrap "${args[@]}" /usr/bin/bash -c '
  socat TCP4-LISTEN:3128,bind=127.0.0.1,reuseaddr,fork UNIX-CONNECT:/bridge/egress.sock >/tmp/egress.log 2>&1 &
  sleep .3
  exec /usr/bin/bash /home/app/workspace-refresh-loop.sh
'
