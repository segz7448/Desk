#!/usr/bin/env bash
set -euo pipefail
root=/home/sandbox/desk
dir="$root/tailscale/tailscale_1.102.2_amd64"
mkdir -p "$root/state/tailscale"
chmod 700 "$root/state/tailscale"
# This host only has 169.254/16 behind NAT. Tailscale incorrectly detects no network
# and pauses login forever; it is reachable as verified by its ts2021 diagnostic.
export TS_ASSUME_NETWORK_UP_FOR_TEST=1
exec "$dir/tailscaled" --tun=userspace-networking --socket="$root/state/tailscale/tailscaled.sock" --state="$root/state/tailscale/tailscaled.state" --statedir="$root/state/tailscale"
