# Proton Everything Bridge

A unified bridge that makes **Proton Mail**, **Proton Calendar**, **Proton
Contacts**, and **Proton Drive** work with any standard desktop app through
open protocols (IMAP, SMTP, CalDAV, CardDAV, WebDAV).

Think of it as Proton Mail Bridge, but for *everything* Proton offers.

## How it works

Proton Everything Bridge runs as a single app on your machine. It translates
Proton's encrypted APIs into standard protocols that any email client, calendar
app, contacts manager, or file browser can speak:

```
         Your Apps
  (Thunderbird, Apple Mail,
   GNOME Calendar, Finder...)
             |
  ┌──────────┼──────────────┐
  │          │              │
IMAP/SMTP  CalDAV  CardDAV  WebDAV
  :1143     :9842   :8080   :9844
  :1025
  │          │       │       │
  └──────────┼───────┼───────┘
             │       │
     hydroxide    proton-     rclone
     (embedded)   calendar-   serve
                  bridge      webdav
             │       │       │
             └───────┼───────┘
                     │
          Proton API (encrypted)
```

| Service | Protocol | Port | Backend |
|---------|----------|------|---------|
| Mail (incoming) | IMAP | 1143 | [hydroxide](https://github.com/emersion/hydroxide) |
| Mail (outgoing) | SMTP | 1025 | hydroxide |
| Contacts | CardDAV | 8080 | hydroxide |
| Calendar | CalDAV | 9842 | [proton-calendar-bridge](https://github.com/terraceonhigh/proton-calendar-bridge) |
| Drive | WebDAV | 9844 | [rclone](https://rclone.org/) `serve webdav` |

## Four Modes

The project is designed with progressive levels of integration. Each mode works
independently, so even if the fancier modes aren't ready yet, simpler ones
always work.

### Mode 1: Bash Script (works today)

Dead simple. Starts each service as its own process. Each handles its own
authentication. No Go compilation needed.

```bash
./scripts/start-all.sh
```

Requires hydroxide, proton-calendar-bridge, and rclone to be installed and
authenticated separately. See [Setup](#setup) below.

### Mode 2: TUI Dashboard

A single Go binary that manages all services and shows a live ASCII dashboard
with connection details and health status:

```
╔═══════════════════════════════════════════╗
║  Proton Everything Bridge                 ║
╠═══════════════════════════════════════════╣
║  IMAP                        ● Running   ║
║  Host: 127.0.0.1   Port: 1143            ║
╠───────────────────────────────────────────╣
║  SMTP                        ● Running   ║
║  Host: 127.0.0.1   Port: 1025            ║
╠───────────────────────────────────────────╣
║  CardDAV                     ● Running   ║
║  URL: http://127.0.0.1:8080/             ║
╠───────────────────────────────────────────╣
║  CalDAV                      ● Running   ║
║  URL: http://127.0.0.1:9842/caldav/      ║
╠───────────────────────────────────────────╣
║  WebDAV                      ● Running   ║
║  URL: http://127.0.0.1:9844/             ║
╚═══════════════════════════════════════════╝
```

```bash
go build -o proton-bridge-tui ./cmd/proton-bridge-tui/
./proton-bridge-tui
```

Hydroxide (IMAP, SMTP, CardDAV) runs embedded in-process. Calendar bridge and
rclone run as managed child processes with health monitoring.

### Mode 3: Unified Auth (planned)

Same TUI, but you log in once and the app provisions credentials for all three
backends automatically. No separate authentication per service.

### Mode 4: GUI (planned)

A native desktop app (Wails v2 + Svelte) that looks and behaves like Proton
Mail Bridge, but with additional cards for CalDAV, CardDAV, and WebDAV
connection details. System tray, dark theme, copy-to-clipboard buttons.

## Setup

### Prerequisites

- **Go 1.24+** for building the TUI (`brew install go` or your package manager)
- **rclone** for Proton Drive support (`brew install rclone`)
- **proton-calendar-bridge** for CalDAV (build from submodule)

### 1. Clone and initialize

```bash
git clone --recurse-submodules https://github.com/terraceonhigh/Proton-Everything-Bridge.git
cd Proton-Everything-Bridge

# If you already cloned without --recurse-submodules:
git submodule update --init --recursive
```

### 2. Authenticate each service

**Hydroxide (Mail + Contacts):**
```bash
go install github.com/emersion/hydroxide/cmd/hydroxide@latest
hydroxide auth your@proton.me
# Enter your Proton password, then note the bridge password
```

**Calendar Bridge:**
```bash
cd proton-calendar-bridge
go build -o proton-calendar-bridge ./cmd/proton-calendar-bridge/...
./proton-calendar-bridge --login
```

**rclone (Drive):**
```bash
rclone config
# Create a new remote: name "proton", type "protondrive", follow prompts
```

### 3. Run

**Mode 1** (simplest):
```bash
./scripts/start-all.sh
```

**Mode 2** (TUI dashboard):
```bash
go build -o proton-bridge-tui ./cmd/proton-bridge-tui/
./proton-bridge-tui
```

### 4. Configure your apps

Point your apps at `127.0.0.1` with the ports listed above. Use the bridge
password from hydroxide as the password for IMAP/SMTP/CardDAV.

| App | Settings |
|-----|----------|
| Thunderbird | IMAP: 127.0.0.1:1143 (STARTTLS), SMTP: 127.0.0.1:1025 (SSL) |
| Apple Mail | IMAP: 127.0.0.1:1143, SMTP: 127.0.0.1:1025 |
| GNOME Calendar | CalDAV: http://127.0.0.1:9842/caldav/ |
| macOS Contacts | CardDAV: http://127.0.0.1:8080/ |
| Finder / Nautilus | WebDAV: http://127.0.0.1:9844/ |

## Project Structure

```
Proton-Everything-Bridge/
├── scripts/start-all.sh            # Mode 1: bash launcher
├── cmd/
│   ├── proton-bridge-tui/          # Mode 2/3: TUI dashboard
│   └── proton-everything-bridge/   # Mode 4: GUI (stub)
├── internal/
│   ├── config/                     # Unified configuration
│   ├── supervisor/                 # Service lifecycle management
│   │   ├── embedded.go             #   hydroxide in-process
│   │   ├── process.go              #   child process management
│   │   ├── health.go               #   TCP/HTTP health probes
│   │   └── supervisor.go           #   orchestrator
│   ├── tui/                        # bubbletea dashboard
│   └── auth/                       # Unified auth provisioning
├── hydroxide/                      # Submodule: IMAP+SMTP+CardDAV
├── proton-calendar-bridge/         # Submodule: CalDAV
├── proton-drive-bridge/            # Submodule: (reference)
├── proton-mail-bridge/             # Submodule: (replaced by hydroxide)
└── desktop/                        # GNOME plugin (see TODO.md)
```

## How We Got Here

This project evolved through several architectural iterations:

1. **Docker-based server** (v1): Originally attempted to run all bridges in
   Docker containers behind a unified API server. Proved too complex and
   fragile for a desktop app use case.

2. **Stripped to submodules** (v2): Removed all Docker/server infrastructure.
   Kept the three bridge repos as git submodules with manual build instructions.
   Added a GNOME Online Accounts plugin in C for Linux desktop integration.

3. **Hydroxide pivot** (v3, current): Discovered that
   [hydroxide](https://github.com/emersion/hydroxide) — a pure Go third-party
   Proton bridge — provides IMAP, SMTP, *and* CardDAV in a single embeddable
   library. This eliminated the need for the official C/C++/Go proton-mail-bridge
   (which was hard to build and impossible to embed) and added CardDAV support
   that wasn't available before.

   **Key architectural decisions:**
   - **Hydroxide replaces proton-mail-bridge** for IMAP/SMTP/CardDAV. Pure Go,
     no C dependencies, importable as a library via `replace` directive in go.mod.
   - **proton-calendar-bridge runs as a child process** because all its code is
     under Go's `internal/` directory and cannot be imported externally.
   - **rclone runs as a child process** because its WebDAV serve constructor is
     unexported. `rclone serve webdav proton:` is battle-tested and reliable.
   - **Four progressive modes** ensure there's always a working fallback — even
     if the GUI never ships, the bash script and TUI dashboard work.
   - **Wails v2** chosen for the future GUI over Fyne (better CSS theming for
     matching Proton's dark theme) and Tauri (avoids adding Rust to a Go project).

## Design Principles

1. **Maximum Recycling** — Wrap existing tools, don't reinvent. hydroxide,
   proton-calendar-bridge, and rclone do the heavy lifting.
2. **No New Crypto** — Bridges handle all Proton encryption, SRP auth, and PGP.
   Our code only speaks standard protocols.
3. **Open Standards** — Every service is exposed via its RFC-defined protocol:
   IMAP (RFC 3501), SMTP (RFC 5321), CalDAV (RFC 4791), CardDAV (RFC 6352),
   WebDAV (RFC 4918).
4. **Progressive Enhancement** — Each mode works independently. The bash script
   is the "it always works" fallback.

## Platform Support

| Platform | Mode 1 (Bash) | Mode 2 (TUI) | Mode 3 (Auth) | Mode 4 (GUI) |
|----------|--------------|--------------|---------------|--------------|
| macOS (ARM) | Yes | Yes | Planned | Planned |
| macOS (x86) | Yes | Yes | Planned | Planned |
| Linux | Yes | Yes | Planned | Planned |
| Windows | WSL/Git Bash | Yes | Planned | Planned |

## License

GPL-2.0-only — see [LICENSE](LICENSE).
