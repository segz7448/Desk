#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")" && pwd)
PROJECT=$(cd -- "$ROOT/../.." && pwd)
STATE="$PROJECT/state"
mkdir -p "$ROOT/bridge" "$STATE/home/Desktop" "$STATE/home/Documents" "$STATE/home/workspace" "$STATE/deliverables" "$STATE/etc" "$STATE/feed"
chmod 700 "$ROOT/bridge" "$STATE/home" "$STATE/etc" "$STATE/feed" "$STATE/home/workspace" "$STATE/deliverables"
if [ ! -f "$STATE/feed/status.json" ]; then cp "$ROOT/status.json" "$STATE/feed/status.json"; fi
mkdir -p "$STATE/home/.config/xfce4/xfconf/xfce-perchannel-xml" "$STATE/home/.config/autostart"
if [ ! -f "$STATE/home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml" ]; then
  sed -e "/<value type=\"int\" value=\"9\"\\/>/d" -e "/<property name=\"plugin-9\"/d" /etc/xdg/xfce4/panel/default.xml > "$STATE/home/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml"
fi
# Copy only public, synthetic identity/network files. Never bind the host /etc or home.
printf 'deskguest:x:%s:%s:Desk Guest:/home/deskguest:/bin/bash\n' "$(id -u)" "$(id -g)" > "$STATE/etc/passwd"
printf 'deskguest:x:%s:\n' "$(id -g)" > "$STATE/etc/group"
printf '127.0.0.1 localhost\n' > "$STATE/etc/hosts"
printf 'nameserver 10.0.2.3\n' > "$STATE/etc/resolv.conf"
printf 'desk-remote-pc\n' > "$STATE/etc/hostname"
if [ ! -f "$STATE/etc/machine-id" ]; then cat /proc/sys/kernel/random/uuid | tr -d '-' > "$STATE/etc/machine-id"; fi
cat > "$STATE/home/Desktop/Control Room.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Control Room
Comment=Curated status board
Exec=/usr/bin/python3 /home/app/desktop.py
Icon=utilities-system-monitor
Terminal=false
DESKTOP
chmod 755 "$STATE/home/Desktop/Control Room.desktop"
# A terminal and file manager are actual apps within a fresh, persistent *guest-only* home.
for pair in 'Terminal:xfce4-terminal:utilities-terminal' 'Files:thunar:system-file-manager' 'Editor:mousepad:accessories-text-editor'; do
 IFS=: read -r name cmd icon <<< "$pair"
 cat > "$STATE/home/Desktop/$name.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$cmd
Icon=$icon
Terminal=false
DESKTOP
 chmod 755 "$STATE/home/Desktop/$name.desktop"
done
# System applications and shared libraries are read-only. Only the guest home and VNC
# Unix socket bridge are writable host binds; both were created for this instance.
args=(--die-with-parent --unshare-all --hostname desk-remote-pc
  --ro-bind /usr /usr --ro-bind /etc/xdg /etc/xdg --ro-bind /etc/fonts /etc/fonts
  --ro-bind /etc/ssl/certs /etc/ssl/certs --proc /proc --dev /dev
  --tmpfs /tmp --tmpfs /home --tmpfs /run --tmpfs /var --dir /dev/shm --dir /etc --dir /opt --dir /opt/google
  --bind "$STATE/home" /home/deskguest --ro-bind "$ROOT" /home/app
  --ro-bind "$STATE/feed" /home/feed
  --ro-bind "$STATE/deliverables" /home/deliverables
  --bind "$ROOT/bridge" /bridge
  --ro-bind "$STATE/etc/passwd" /etc/passwd --ro-bind "$STATE/etc/group" /etc/group
  --ro-bind "$STATE/etc/hosts" /etc/hosts --ro-bind "$STATE/etc/resolv.conf" /etc/resolv.conf
  --ro-bind "$STATE/etc/hostname" /etc/hostname --ro-bind "$STATE/etc/machine-id" /etc/machine-id
  --symlink usr/bin /bin --symlink usr/lib /lib --symlink usr/lib64 /lib64
  --setenv HOME /home/deskguest --setenv USER deskguest --setenv LOGNAME deskguest
  --setenv PATH /usr/bin:/bin --setenv XDG_CONFIG_HOME /home/deskguest/.config
  --setenv http_proxy http://127.0.0.1:3128 --setenv https_proxy http://127.0.0.1:3128
  --setenv no_proxy localhost,127.0.0.1
  --setenv GIT_CONFIG_NOSYSTEM 1)
# Dev tools use read-only system binaries; only the guest home is writable.
if command -v gedit >/dev/null; then
  cat > "$STATE/home/Desktop/Code.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Code Editor
Exec=/usr/bin/gedit
Icon=accessories-text-editor
Terminal=false
DESKTOP
  chmod 755 "$STATE/home/Desktop/Code.desktop"
fi
for pair in 'Image Viewer:ristretto:ristretto' 'Archives:xarchiver:package-x-generic'; do
  IFS=: read -r name cmd icon <<< "$pair"
  if command -v "$cmd" >/dev/null; then
    cat > "$STATE/home/Desktop/$name.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=$name
Exec=$cmd
Icon=$icon
Terminal=false
DESKTOP
    chmod 755 "$STATE/home/Desktop/$name.desktop"
  fi
done
# Firefox ESR from the system package is mounted read-only.
if [ -d /usr/lib/firefox-esr ]; then
  args+=(--ro-bind /usr/lib/firefox-esr /usr/lib/firefox-esr)
  cat > "$STATE/home/Desktop/Browser.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Browser
Exec=/usr/lib/firefox-esr/firefox-esr --no-remote --profile /home/deskguest/.mozilla/desk https://example.com/
Icon=web-browser
Terminal=false
DESKTOP
  chmod 755 "$STATE/home/Desktop/Browser.desktop"
  mkdir -p "$STATE/home/.mozilla/desk"
  cat > "$STATE/home/.mozilla/desk/user.js" <<'FIREFOX'
user_pref("network.proxy.type", 1);
user_pref("network.proxy.http", "127.0.0.1");
user_pref("network.proxy.http_port", 3128);
user_pref("network.proxy.ssl", "127.0.0.1");
user_pref("network.proxy.ssl_port", 3128);
user_pref("network.proxy.no_proxies_on", "");
user_pref("network.proxy.share_proxy_settings", true);
user_pref("network.proxy.socks_remote_dns", true);
user_pref("browser.startup.homepage", "https://example.com/");
FIREFOX
fi
# Optional Chrome binary is host-mounted read-only. It sees only this namespace.
# The egress proxy is still the only web route.
if [ "${DESK_CHROME_PATH:-}" ]; then
  args+=(--ro-bind "$DESK_CHROME_PATH" /opt/google/chrome)
  cat > "$STATE/home/Desktop/Browser.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Browser
Exec=/opt/google/chrome/chrome --no-sandbox --no-first-run --no-default-browser-check --homepage=https://example.com --password-store=basic --disable-dev-shm-usage --disable-gpu --user-data-dir=/home/deskguest/.config/chrome --proxy-server=http://127.0.0.1:3128 --disable-features=AsyncDns
Icon=web-browser
Terminal=false
DESKTOP
  chmod 755 "$STATE/home/Desktop/Browser.desktop"
fi
exec bwrap "${args[@]}" /usr/bin/bash -c '
  set -e
  mkdir -p /tmp/.X11-unix && chmod 1777 /tmp/.X11-unix
  export DISPLAY=:1
  Xvfb :1 -screen 0 1440x900x24 -nolisten tcp >/tmp/xvfb.log 2>&1 &
  sleep 1
  /usr/bin/bash /home/app/workspace-refresh-loop.sh >/tmp/workspace-refresh.log 2>&1 &
  dbus-run-session -- xfce4-session >/tmp/xfce.log 2>&1 &
  sleep 2
  x11vnc -localhost -rfbport 5998 -forever -shared -nopw -o /tmp/x11vnc.log >/tmp/vnc-start.log 2>&1 &
  sleep 1
  socat UNIX-LISTEN:/bridge/vnc.sock,fork,mode=0600,unlink-early TCP4:127.0.0.1:5998 >/tmp/socat.log 2>&1 &
  if [ -S /bridge/egress.sock ]; then
    socat TCP4-LISTEN:3128,bind=127.0.0.1,reuseaddr,fork UNIX-CONNECT:/bridge/egress.sock >/tmp/egress-bridge.log 2>&1 &
  fi
  /usr/bin/python3 /home/app/feed-observer.py >/tmp/observer.log 2>&1 &
  wait
'
