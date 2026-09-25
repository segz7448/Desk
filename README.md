# Desk

An isolated, mouse-only live control-room display. The desktop shows a dated, curated status board, a feed-observer log produced inside its own sandbox, and a local process/CPU/memory monitor. It does **not** stream the host desktop or expose a shell. The login gateway uses SQLite sessions, and a Cloudflare Tunnel can put the gateway behind a public HTTPS hostname.

## Stack

- Linux bubblewrap namespace with no network, temporary home/run/tmp, a read-only application + feed mount, and a single VNC socket bridge
- Xvfb and x11vnc with `-input MB` (mouse only), a GTK 3 desktop application, and an isolated feed-observer process
- websockify/noVNC for browser viewing; Node.js HTTP gateway, `better-sqlite3`, scrypt password hashing, and server-side sessions
- Cloudflare Tunnel for public routing (optional; bring your own account and tunnel)

## Setup

Requires Linux with `bwrap`, `Xvfb`, `x11vnc`, `socat`, Python 3 GTK/GI bindings, Python `websockify`, Node.js and npm. Run in a dedicated non-privileged user account on a host you control. This is an illustrative source release, not a turn-key security certification.

```sh
npm install
export DESK_HOSTNAMES='desk.example.com'     # comma-separated exact hostnames
export DESK_LOGIN='desk'
export DESK_DB_PATH="$PWD/state/auth.sqlite"
# Pipe a newly chosen password (at least 12 characters) into the initializer;
# never commit it, put it in a shell argument, or reuse the sample data as real reports.
read -rs PASSWORD; printf '%s' "$PASSWORD" | npm run init-login; unset PASSWORD
./scripts/isolated-display.sh
```

In separate terminals, run `./scripts/websockify.sh` and `npm start`. The gateway listens only on `127.0.0.1:6081` and requires `X-Forwarded-Proto: https` and an exact configured Host. Configure a Cloudflare Tunnel published application route for each hostname to `http://127.0.0.1:6081`. Set the corresponding DNS route in your own Cloudflare account. Do not expose ports 6080 or 6081 directly to the public Internet. The tunnel's ID/token and account details are deliberately not included here; supply them through your own secret management.

Open `https://desk.example.com/` and sign in with `DESK_LOGIN` and the chosen password. The default feed is synthetic `app/status.json`. To run the optional periodic renderer, set `DESK_FEED_INPUT` to a curated JSON file in the same schema and run `./scripts/refresh-feed.sh` on the host. It validates and atomically replaces the display feed every 60 seconds. Only give it data approved for this audience; the display cannot verify an input’s provenance. The GTK desktop rereads the output every minute; the observer prints changes and heartbeat checks every 15 seconds. Feed figures should include their source dates and must not be presented as live payments unless they come from a verified ledger. Do not bind any private host folders or sensitive logs into the sandbox. The display is mouse-only; panel dragging, feed refresh and the status scroll work without keyboard input.

## Boundaries

The isolated desktop has its own network namespace and process namespace. The VNC bridge is a socket in `bridge/` and the app/feed mount is read-only inside the sandbox. The gateway controls browser access with a single database-backed login. A deployment should additionally provide process supervision, HTTPS tunnel monitoring, backups for the login database, dependency updates, and an independent security review. A user who can modify the host, project files or tunnel configuration can bypass the display's boundaries. The terminal-looking pane is a read-only log viewer, not an interactive command prompt.

Never commit `state/`, `.env`, passwords, real reports, tunnel credentials, or log files. The example feed contains synthetic placeholder data only.

## Data flow and watcher coverage

The external status producer writes a curated JSON report using the sample schema. `render-feed.py` checks its shape and atomically replaces the read-only-mounted display copy. The isolated feed observer reports when the snapshot changes; it never queries other accounts or raw logs. Each watcher entry is display data with a scope, cadence, and last report time, not proof that a background watcher is active. Unknown or stale schedules should be labeled as such in the input. Company, pipeline and activity cards likewise show source-dated summaries; update the input before claiming a new result.
