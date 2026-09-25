# Desk

An isolated, mouse-only live control-room display. The desktop shows a dated, curated status board, a feed-observer log produced inside its own sandbox, and a local process/CPU/memory monitor. It does **not** stream the host desktop or expose a shell. The login gateway uses SQLite sessions, and a Cloudflare Tunnel can put the gateway behind a public HTTPS hostname.

## Stack

- Linux bubblewrap namespace with no network, temporary home/run/tmp, a read-only application + feed mount, and a single VNC socket bridge
- Xvfb and x11vnc with `-input MB` (mouse only), a GTK 3 desktop application, and an isolated feed-observer process
- websockify/noVNC for browser viewing; Node.js HTTP gateway, `better-sqlite3`, scrypt password hashing, and server-side sessions
- Cloudflare Tunnel for public routing (optional; bring your own account and tunnel)

## Clone to live (Ubuntu/Debian)

Use a normal non-root user with sudo. This installer installs bubblewrap, Xvfb, x11vnc, GTK 3, Python websockify, SQLite, Node.js 20+ with npm, and cloudflared. It fetches NodeSource setup when the system Node is too old. Review the scripts before running them. This is not a security certification.

```sh
git clone https://github.com/segz7448/Desk.git
cd Desk
bash app/app/setup.sh
# choose a NEW 12+ character password at the prompt
nano .env  # set DESK_HOSTNAMES and CLOUDFLARE_TUNNEL_TOKEN
bash app/app/run.sh
```

Create a Cloudflare Tunnel in your own account, add a published application hostname matching `DESK_HOSTNAMES`, and point it to `http://127.0.0.1:6081`. Put only the tunnel token in local `.env` (chmod 600), never in Git. `DESK_HOSTNAMES` may be a comma-separated list of exact allowed hostnames. The login defaults to `desk`, or set `DESK_LOGIN` in `.env` **before** setup. On first run the setup script prompts for a fresh password and creates `state/auth.sqlite`; only its salted scrypt hash and server-side sessions go into that ignored database. The password is not printed or committed. `state/`, `.env`, logs and tokens are ignored. If no tunnel token is set, the gateway remains localhost-only. It still requires an HTTPS reverse proxy with a matching host and `X-Forwarded-Proto: https`; a direct local browser visit will return 403.

`run.sh` starts the isolated desktop, VNC bridge, login gateway and optional tunnel. Scripts are invoked with `bash` because GitHub web-editor commits may not retain executable file modes. It stops the child process groups on shutdown; use a process supervisor for production. Ports 6080 and 6081 must stay local. The websockify service on 6080 has no login gate of its own, so never expose that port. Open your configured HTTPS hostname and sign in with the chosen login/password.

The default feed is synthetic `app/app/status.json`. Copy `sample/sample/status.json` if you need a clean sample file separate from the display input. An optional host-side `sh app/app/refresh-feed.sh` checks `DESK_FEED_INPUT` every 60 seconds and atomically writes the display file using `render-feed.py`; configure an approved source JSON in the example schema. The GTK desktop rereads every minute; the observer reports changes and heartbeat checks every 15 seconds. Feed claims need dates. The display is mouse-only, with draggable panels, Refresh and scrolling; the terminal-looking pane is a read-only log viewer.

## Boundaries

The isolated desktop has its own network namespace and process namespace. The VNC bridge is a socket in `bridge/` and the app/feed mount is read-only inside the sandbox. The gateway controls browser access with a single database-backed login. A deployment should additionally provide process supervision, HTTPS tunnel monitoring, backups for the login database, dependency updates, and an independent security review. A user who can modify the host, project files or tunnel configuration can bypass the display's boundaries. The terminal-looking pane is a read-only log viewer, not an interactive command prompt.

Never commit `state/`, `.env`, passwords, real reports, tunnel credentials, or log files. The example feed contains synthetic placeholder data only.

## Data flow and watcher coverage

The external status producer writes a curated JSON report using the example schema. `app/app/render-feed.py` checks its shape and atomically replaces the read-only-mounted display copy. The isolated feed observer reports when the snapshot changes; it never queries other accounts or raw logs. Each watcher entry is display data with a scope, cadence, and last report time, not proof that a background watcher is active. Unknown or stale schedules should be labeled as such in the input. Company, pipeline and activity cards likewise show source-dated summaries; update the input before claiming a new result.
