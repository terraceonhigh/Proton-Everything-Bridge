# Proton on GNOME Online Accounts

Makes your **Proton Mail**, **Proton Drive**, **Proton Calendar**, and
**Proton Contacts** work with standard apps — on any device, any OS.

Two modes of operation:

| Mode | What it does | Who it's for |
|------|-------------|--------------|
| **Server** | Docker service exposing Proton via CalDAV, CardDAV, WebDAV, IMAP/SMTP | Anyone — works with iOS, Android, Windows, macOS, Linux |
| **Desktop** | GNOME Online Accounts plugin for direct desktop integration | GNOME desktop users |

---

## Server Mode (Recommended)

Runs a self-hosted server that translates your Proton account into open
standards. Works like Proton Mail Bridge — but for everything.

**Supports multiple Proton accounts** on one server. Each user gets isolated
bridge containers and their own endpoints.

### Install

**Linux / macOS:**
```bash
cd server
bash install-server.sh
```

**Windows** (PowerShell):
```powershell
cd server
.\install-server.ps1
```

The installer sets up Docker, configures access control (localhost, LAN, or
internet), and starts the server. When it finishes:

1. Open **https://your-domain/** in your browser
2. Click **[+ Add Account]**
3. Follow the bridge login instructions
4. Copy the endpoint URLs into your apps

### What you get

| Service | Protocol | Endpoint |
|---------|----------|----------|
| Calendar | CalDAV | `https://server/users/{name}/caldav/` |
| Contacts | CardDAV | `https://server/users/{name}/carddav/` |
| Files | WebDAV | `https://server/users/{name}/webdav/` |
| Mail | IMAP | `server:993` |
| Mail | SMTP | `server:465` |

### Client setup

| Client | How to connect |
|--------|---------------|
| **iOS / macOS** | Settings → Calendar → Add Account → Other → CalDAV |
| **Thunderbird** | New Calendar → Network → CalDAV → enter URL |
| **DAVx5** (Android) | Base URL → enter CalDAV/CardDAV URL |
| **Windows** | Map Network Drive → enter WebDAV URL |
| **GNOME / Nautilus** | Other Locations → Connect to Server → `davs://...` |

### Access control

The server supports four access modes, configured during install:

| Mode | Who can connect |
|------|-----------------|
| `localhost` | Only the server machine (default) |
| `lan` | Devices on your local network |
| `whitelist` | Specific IPs you choose |
| `internet` | Anyone (requires a domain for TLS) |

Authentication is always required regardless of access mode.

### Server commands

```bash
bash install-server.sh --status     # Check what's running
bash install-server.sh --uninstall  # Stop and remove everything

# Logs
docker compose -f docker-compose.caddy.yml logs -f
```

---

## Desktop Mode (GNOME)

A GOA (GNOME Online Accounts) plugin that registers Proton services directly
with GNOME desktop apps.

> Works on **Fedora**, **Ubuntu** (22.04+), **openSUSE**, and **Arch Linux**.

### Install

```bash
bash install.sh
```

Then open **GNOME Settings → Online Accounts → Proton** to add your account.

### What appears

| App | What you see |
|-----|-------------|
| Evolution / Geary | Proton Mail inbox |
| Files / Nautilus | Proton Drive folder |
| GNOME Calendar | Proton Calendar events |

### Desktop commands

```bash
bash install.sh --status     # Check installed components
bash install.sh --uninstall  # Remove everything
```

---

## Architecture

Both modes use the same approach: **wrap existing bridges, expose standard
protocols**.

```
                        Your Apps
                    (any CalDAV/IMAP client)
                            |
                    ┌───────┴────────┐
                    │  Caddy / GOA   │  ← reverse proxy (server) or
                    │  (gateway)     │    GNOME registration (desktop)
                    └───────┬────────┘
          ┌─────────┬───────┼────────┬──────────┐
          │         │       │        │          │
       CalDAV    CardDAV  WebDAV  IMAP/SMTP   │
       proton-   hydroxide rclone  proton-    │
       calendar  :8080    serve    mail-      │
       -bridge            webdav   bridge     │
       :9842              :9844    :1143/1025  │
          │         │       │        │          │
          └─────────┴───────┴────────┴──────────┘
                            │
                    Proton API (encrypted)
```

### Design principles

- **Maximum Recycling**: Wrap existing tools, don't reinvent them
- **No New Crypto**: Bridges handle all encryption and auth with Proton
- **Open Standards**: CalDAV, CardDAV, WebDAV, IMAP/SMTP — universal client support

---

## For Developers

### Building the GNOME plugin from source

```bash
# Install dependencies (Debian/Ubuntu)
sudo apt install meson ninja-build pkg-config \
  libgoa-backend-1.0-dev libglib2.0-dev libsecret-1-dev \
  libsoup-3.0-dev libjson-glib-dev libadwaita-1-dev

# Build
meson setup builddir
ninja -C builddir

# Install
sudo ninja -C builddir install
```

### Server dashboard development

The server dashboard is a Go + htmx application in `server/dashboard/`.

```bash
cd server/dashboard
go build -o dashboard .
```

### Project structure

```
server/                          # Server mode
├── docker-compose.caddy.yml     # Shared infrastructure (Caddy + dashboard)
├── docker-compose.user.yml      # Per-user bridge template
├── dashboard/                   # Go + htmx web panel
├── containers/                  # Bridge Dockerfiles
├── Caddyfile                    # Reverse proxy config
└── install-server.sh            # Guided installer

src/goabackend/                  # Desktop mode (GNOME plugin)
data/                            # systemd user services
install.sh                       # Desktop installer
```

## Documentation

- [Account Setup Flow](docs/account-setup-flow.md) — Detailed setup guide
- [Project Design](PROJECT_DESIGN.md) — Architecture and design decisions
- [Build Plan](MASTER_BUILD_PLAN.md) — GNOME plugin implementation details

## License

GPL-2.0-only — see [LICENSE](LICENSE).
