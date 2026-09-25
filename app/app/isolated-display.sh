#!/bin/sh
set -eu
ROOT=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$ROOT/bridge"
# The only project path visible to the display is the read-only application and sample/curated feed.
exec bwrap --unshare-all --ro-bind /usr /usr --ro-bind /etc /etc --proc /proc --dev /dev \
  --tmpfs /tmp --tmpfs /home --tmpfs /run --tmpfs /var --dir /dev/shm \
  --ro-bind "$ROOT" /home/room --bind "$ROOT/bridge" /bridge \
  --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64 \
  --setenv HOME /home --setenv USER deskguest --setenv LOGNAME deskguest --setenv PATH /usr/bin:/bin \
  /usr/bin/sh -c '
    set -e
    mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
    Xvfb :1 -screen 0 1280x800x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
    sleep 1
    DISPLAY=:1 x11vnc -localhost -rfbport 5998 -forever -shared -nopw -input MB -bg -o /tmp/x11vnc.log >/tmp/vnc-start.log 2>&1
    socat UNIX-LISTEN:/bridge/vnc.sock,fork,mode=0600 TCP4:127.0.0.1:5998 >/tmp/socat.log 2>&1 &
    /usr/bin/python3 /home/room/feed-observer.py >/tmp/observer.log 2>&1 &
    DISPLAY=:1 /usr/bin/python3 /home/room/desktop.py >/tmp/desktop.log 2>&1 &
    wait
  '
