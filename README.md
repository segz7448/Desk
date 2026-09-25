# Desk Remote PC

Desk is an Xfce virtual desktop served in a browser. It has working mouse and keyboard input, terminal, file manager, text editor, and a Firefox ESR browser. The Control Room icon opens a separate, source-dated GTK status board. It is not a stream of the host machine; the desktop runs in a separate bubblewrap mount, PID and network namespace.

## Clone to live (Ubuntu/Debian)

Run as a normal non-root account with sudo. Review the scripts first. The installer installs bubblewrap, Xvfb, x11vnc, Xfce, GTK, Thunar, Mousepad, websockify, SQLite, Firefox ESR, Node.js 20+, npm and cloudflared, then creates a fresh login with a password you enter. Shell scripts are invoked with `bash`/`sh` because GitHub's web editor may leave them mode 0644.

```sh
git clone https://github.com/segz7448/Desk.git
cd Desk
bash app/app/setup.sh
# choose a new 12+ character password when prompted
nano .env  # set DESK_HOSTNAMES and a new CLOUDFLARE_TUNNEL_TOKEN
bash app/app/run.sh
```

Create a Cloudflare Tunnel in your own account with a published application hostname exactly matching `DESK_HOSTNAMES` and an origin of `http://127.0.0.1:6081`. The tunnel token belongs only in local `.env`, never Git. Keep 6080 and 6081 bound to localhost; 6080 has no independent login. The gateway requires a matching HTTPS host and `X-Forwarded-Proto: https`, so a direct localhost browser visit returns 403. The login defaults to `desk`; change `DESK_LOGIN` in `.env` **before** running setup if desired. Setup creates `state/auth.sqlite` with a salted password hash. `state/`, `.env`, sessions, and logs are ignored. The launcher stops its child groups when terminated; use a supervisor for production.

On launch, use the desktop icons for Terminal, Files, Editor, Control Room, and Browser. It runs at 1440x900. Xfce, Thunar and Mousepad are installed by setup. The Control Room uses `state/feed/status.json` seeded with synthetic data; set `DESK_FEED_INPUT` in `.env` to an approved source in the sample schema, then run `sh app/app/refresh-feed.sh` on the host to validate and refresh it every minute. Its figures are dated reports, not a live payment ledger or proof of active watchers. Do not supply private data unless it is approved for this audience.

### Browser and outbound web

Setup installs Firefox ESR and a Browser desktop shortcut. Firefox runs from a read-only system bundle inside the guest and uses the HTTPS proxy. If Chrome is already installed, optionally set `DESK_CHROME_PATH` to its bundle directory, such as `/opt/google/chrome`, in `.env`; the Browser shortcut then uses Chrome instead. Chrome is started with `--no-sandbox` because the outer bubblewrap namespace is the security boundary; this reduces defense in depth. The desktop has no direct host network identity. `egress-proxy.py` provides outbound HTTPS on port 443 only through a Unix socket into the guest's localhost. It checks **all** DNS answers for global public IPs and pins the remote connection to a checked address. It refuses loopback, private, link-local, reserved addresses and other ports. No host service is routed into the guest. Ordinary HTTP and arbitrary TCP are unavailable. Review this boundary independently before using it for untrusted browsing. Chrome is optional; Firefox is installed by the setup script.

The public repo contains no browser profiles, passwords, tunnel identifiers, account details or real reports. The host only binds a dedicated persistent guest home (`state/home`), read-only app source, read-only curated feed and a two-socket bridge. Host `/home`, `/memory`, `/skills`, private `/etc` and other host paths are not visible. A guest can edit its guest home but not host files. The guest can inspect its environment; this isolation is not a formal security certification. Someone who can edit the host installation or tunnel can bypass the boundary.

## Architecture

- Xvfb + Xfce window manager and desktop, x11vnc with both keyboard and mouse, Unix VNC socket to websockify and noVNC.
- Node gateway with exact-host and HTTPS checks, SQLite-backed login, scrypt password hash, one-hour server-side sessions, rate limiting, and authenticated WebSocket upgrades.
- Bubblewrap mount/PID/network namespaces; Xfce, shell, GTK and browser binaries are read-only system applications; guest home persists separately.
- Restricted HTTPS CONNECT relay, no direct guest network; optional Cloudflare Tunnel fronts only the authenticated gateway.
- Source-dated GTK Control Room, isolated feed observer, optional validated renderer.

For troubleshooting, `app/app/check-isolation.sh` can be run inside the guest terminal: `bash /home/app/check-isolation.sh && cat ~/isolation-check.txt`. It reports identity, visible paths, namespace, processes and route. Do not publish its output from a real deployment without reviewing it.
