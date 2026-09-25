#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd -- "$(dirname -- "$0")/../.." && pwd)
cd "$ROOT"
if [ "$(id -u)" -eq 0 ]; then echo 'Run as a normal user with sudo access, not root.' >&2; exit 1; fi
if ! command -v apt-get >/dev/null; then echo 'Ubuntu/Debian with apt-get is required.' >&2; exit 1; fi
sudo apt-get update
sudo apt-get install -y bubblewrap xvfb x11vnc socat python3 python3-gi gir1.2-gtk-3.0 python3-websockify nodejs npm curl ca-certificates sqlite3
npm install
if ! command -v cloudflared >/dev/null; then
  arch=$(dpkg --print-architecture)
  case "$arch" in amd64|arm64) ;; *) echo "Unsupported cloudflared architecture: $arch" >&2; exit 1;; esac
  curl --fail --location --silent --show-error "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-${arch}.deb" -o /tmp/desk-cloudflared.deb
  sudo dpkg -i /tmp/desk-cloudflared.deb
  rm -f /tmp/desk-cloudflared.deb
fi
mkdir -p state app/app/bridge
chmod 700 state app/app/bridge
if [ ! -f .env ]; then cp .env.example .env; chmod 600 .env; fi
set -a; source ./.env; set +a
if [ ! -f "${DESK_DB_PATH:-state/auth.sqlite}" ]; then
  echo 'Choose a fresh login password (12+ characters). It will be stored only as a salted scrypt hash in state/auth.sqlite.'
  read -r -s -p 'Password: ' password; echo
  if [ ${#password} -lt 12 ]; then echo 'Password too short' >&2; exit 1; fi
  printf '%s' "$password" | npm run init-login
  unset password
fi
echo 'Install complete. Edit .env (hostname and tunnel token), then ./app/app/run.sh.'
