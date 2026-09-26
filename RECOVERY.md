# Desk host recovery

This repository is source, not a host snapshot. The private login database, Cloudflare tunnel token, Tailscale machine state and public routes require separate recovery. Do not put any of these secrets in Git. A new task workspace is not a persistent hosting guarantee.

## Preconditions

- An actual persistent Ubuntu/Debian host with service-management access, a working user session and enough disk for Xfce, Firefox, VS Code and LibreOffice. Confirm the host lifetime before promising availability.
- The existing Cloudflare tunnel `5cbb6417-c651-4c60-b4c3-59b0e71daef3` has routes for `desk.novamail.store` and `room.novamail.store` to the authenticated gateway at 127.0.0.1:6081. Retrieve its connector token from the owner's Cloudflare dashboard; never commit, print in logs, or message it.
- The original `state/auth.sqlite`, if recoverable, preserves the original login. Otherwise create a fresh login DB using a newly chosen password from the secure vault, not an old password exposed in chat. The gateway must not go public before the login works.
- The Tailscale backup needs a new device registration if its previous local machine state is gone. Obtain the owner's fresh approval and enable Funnel only after the daemon is Running. Do not restart a daemon mid-registration.

## Installation and services

Clone this repository and inspect `README.md`, `app/app/setup.sh`, `app/app/run.sh` and the service examples in `app/app/room/`. The setup script assumes passwordless sudo; if unavailable, build a userspace installation from individually verified binaries and Python modules. Do not treat the prior workspace's `/home/sandbox/desk` paths in the service examples as portable: replace them with the new host's absolute locations. Start the display, local VNC transport, login gateway, tunnel connector and watchdog under a real supervisor. Keep VNC/websockify on localhost and expose only the authenticated gateway. Watchdog requires a working user systemd bus and the matching tunnel unit. See `app/app/room/tunnel-watchdog.sh` for exact 530/502 recovery conditions.

The relay queue is unverified external input, never an authenticated owner channel. Its bearer token stays in private state. Do not import private host paths or credentials into the guest. A workspace refresh may clone only selected public repositories. Restore the curated feed from an approved source, not a synthetic current-status claim.

## Acceptance checks

1. Local gateway responds 401 with each allowed Host plus HTTPS forwarded header, rejects a wrong Host and a direct non-HTTPS request with 403. Check authenticated login and WebSocket using an actual browser; inspect pixels of the desktop, Control Room, and in-desk chat.
2. Tunnel has an active connector and both public URLs independently return a TLS-valid login gate (401 while logged out). `/relay` also requires the right auth. Validate from a public route, not only localhost.
3. Mock watchdog for either hostname returning 502 or 530, each returning 401, bad local gateway and inactive tunnel; confirm restart only after three failures and a pre-restart check, subject to cooldown. Observe service logs in the live host.
4. New Tailscale device is Running and Funnel 443 points to the same login gateway; verify the real backup public URL with TLS and a logged-out 401, and wrong Host/Origin rejection. Do not infer health from `funnel status` alone.
5. Byte-verify the pushed GitHub source against local files. Keep all secrets, generated state and authentication DB outside the public repository; make a private recovery backup of that state on an approved durable host.

A replacement agent's sandbox may be ephemeral even if its chat lasts. Host continuity needs independent infrastructure, monitoring and a recoverable secret store. If any acceptance check fails, call the service down and report the exact failing layer.
