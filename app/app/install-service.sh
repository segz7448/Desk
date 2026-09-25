#!/usr/bin/env bash
# Install a user-level watchdog for a fresh Desk installation.
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"
[ -f state/auth.sqlite ] || { echo 'Run setup first' >&2; exit 1; }
command -v systemctl >/dev/null || { echo 'systemd unavailable; use run.sh under your own supervisor' >&2; exit 1; }
unit="$HOME/.config/systemd/user/desk-remote-pc.service"
mkdir -p "$(dirname "$unit")"
cat > "$unit" <<UNIT
[Unit]
Description=Desk isolated desktop stack
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
WorkingDirectory=$ROOT
ExecStart=/usr/bin/bash $ROOT/app/app/run.sh
Restart=always
RestartSec=5
StartLimitIntervalSec=0

[Install]
WantedBy=default.target
UNIT
systemctl --user daemon-reload
systemctl --user enable --now desk-remote-pc.service
echo 'Desk user service enabled. Check with systemctl --user status desk-remote-pc.service.'
if ! loginctl show-user "$USER" -p Linger | grep -q 'Linger=yes'; then
  echo 'Boot without login may require an administrator to enable linger for this account.'
fi
