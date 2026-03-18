# Claude Code Instructions

## Project Overview

This repo provides open-standard bridges for Proton services (Mail, Calendar,
Contacts, Drive) plus a GNOME Online Accounts desktop plugin. The goal is a
unified "Proton Everything Bridge" app that works like Proton Mail Bridge but
also exposes CalDAV, CardDAV, and WebDAV alongside IMAP/SMTP.

## Architecture

**Four progressive modes** (each level works independently if higher levels fail):

1. **Mode 1 — Bash script** (`scripts/start-all.sh`): Starts each service
   independently. Each handles its own auth. Always works.
2. **Mode 2 — TUI dashboard** (`cmd/proton-bridge-tui/`): Go binary with
   bubbletea ASCII dashboard showing service status and credentials. Separate
   logins per service.
3. **Mode 3 — Unified auth** (same binary, `--login` flag): Single Proton
   login provisions all backend credential stores.
4. **Mode 4 — GUI** (`cmd/proton-everything-bridge/`): Wails v2 + Svelte
   frontend matching Proton Mail Bridge dark theme. Stub only for now.

**Backend components:**

| Protocol | Backend | Integration |
|----------|---------|-------------|
| IMAP :1143 | hydroxide | Embedded (Go library) |
| SMTP :1025 | hydroxide | Embedded (Go library) |
| CardDAV :8080 | hydroxide | Embedded (Go library) |
| CalDAV :9842 | proton-calendar-bridge | Child process |
| WebDAV :9844 | rclone serve webdav | Child process |

## Current State

### What exists

- **Root Go module** (`go.mod`) with `replace` directive for hydroxide submodule
- **`scripts/start-all.sh`** — Mode 1 bash launcher (complete)
- **`internal/config/`** — Unified configuration (ports, paths, preferences)
- **`internal/supervisor/`** — Service lifecycle management:
  - `service.go` — Service interface and status types
  - `health.go` — TCP/HTTP health probes
  - `embedded.go` — Hydroxide in-process wrapper (IMAP+SMTP+CardDAV)
  - `process.go` — Child process wrapper (calendar bridge, rclone)
  - `supervisor.go` — Top-level orchestrator
- **`internal/tui/`** — bubbletea TUI dashboard with Proton dark theme
- **`internal/auth/`** — Unified auth provisioning:
  - `hydroxide.go` — Provisions hydroxide credentials via exported auth package
  - `calendar.go` — Duplicates calendar bridge's AES-256-GCM store format
  - `rclone.go` — Writes rclone.conf with obscured password
  - `unified.go` — Orchestrates single-login across all backends
- **`cmd/proton-bridge-tui/`** — Mode 2/3 entry point
- **`cmd/proton-everything-bridge/`** — Mode 4 stub

### Submodules

- `hydroxide/` — emersion/hydroxide (IMAP+SMTP+CardDAV, pure Go, MIT)
- `proton-calendar-bridge/` — terraceonhigh fork (CalDAV, Go, MIT)
- `proton-drive-bridge/` — terraceonhigh fork (kept for reference)
- `proton-mail-bridge/` — terraceonhigh fork (replaced by hydroxide)

### What's next

- Run `go mod tidy` and verify the build compiles
- Test Mode 1 bash script with actual services
- Test Mode 2 TUI dashboard
- Implement go-proton-api auth call for calendar bridge provisioning (Mode 3)
- Build Mode 4 GUI with Wails v2 + Svelte

## Key Technical Decisions

- **Hydroxide replaces proton-mail-bridge** — pure Go, no C/C++ deps, embeddable
- **Calendar bridge runs as child process** — all code is in `internal/`, can't import
- **rclone runs as child process** — serve constructor is unexported
- **Unified auth authenticates twice** — once via hydroxide's protonmail.Client
  (legacy v3 API), once via go-proton-api (v4) for calendar bridge. Same credentials.
- **Wails v2 for GUI** — web frontend (CSS) for pixel-perfect Proton dark theme

## Design Principles

1. **Maximum Recycling**: Wrap existing tools, don't reinvent
2. **No New Crypto**: Bridges handle all Proton encryption
3. **Open Standards**: CalDAV, CardDAV, WebDAV, IMAP/SMTP
4. **Progressive Enhancement**: Each mode works independently
