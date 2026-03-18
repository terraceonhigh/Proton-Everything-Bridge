# Project Design: Proton Everything Bridge

## Vision

A unified desktop app that behaves like Proton Mail Bridge but exposes *all*
Proton services through open standard protocols: IMAP, SMTP, CalDAV, CardDAV,
and WebDAV. One app, one login, all of Proton in your native apps.

## Design Philosophy

### Maximum Recycling

Wrap battle-tested bridges — don't build new ones. hydroxide provides
IMAP/SMTP/CardDAV, proton-calendar-bridge provides CalDAV, rclone provides
WebDAV. Our code is orchestration glue.

### No New Crypto

We never implement PGP, SRP, or Proton authentication. The bridges handle
all cryptographic operations. Our code only speaks standard protocols.

### Open Standards First

Every service is exposed via its RFC-defined protocol. No proprietary APIs
leak to clients.

### Progressive Enhancement

Four modes of operation, each more integrated than the last, each working
independently. The bash script is the "it always works" fallback.

## Component Map

| Service | Protocol | RFC | Backend | Integration |
|---------|----------|-----|---------|-------------|
| Mail (in) | IMAP | 3501 | hydroxide | Embedded (Go library) |
| Mail (out) | SMTP | 5321 | hydroxide | Embedded (Go library) |
| Contacts | CardDAV | 6352 | hydroxide | Embedded (Go library) |
| Calendar | CalDAV | 4791 | proton-calendar-bridge | Child process |
| Files | WebDAV | 4918 | rclone serve webdav | Child process |

## Architecture

### Why Hydroxide Over Proton Mail Bridge

The official Proton Mail Bridge is a C/C++/Go hybrid with a Qt GUI. It only
provides IMAP and SMTP. It cannot be embedded as a library.

Hydroxide is pure Go, MIT-licensed, and provides IMAP + SMTP + CardDAV with
clean exported packages. It can be imported directly into our Go binary and
run in-process. This eliminates C/C++ build complexity and adds CardDAV
(contacts) support that the official bridge doesn't offer.

### Embedded vs Child Process

**Hydroxide (embedded):** Imported as a Go library via `replace` directive.
The `internal/supervisor/embedded.go` re-implements the ~90 lines of server
setup from `hydroxide/cmd/hydroxide/main.go` using exported packages:
- `hydroxide/imap` — returns an `imap.Backend` interface
- `hydroxide/smtp` — returns an `smtp.Backend` interface
- `hydroxide/carddav` — returns an `http.Handler`
- `hydroxide/auth` — manages encrypted credential store
- `hydroxide/events` — manages event streaming

**Calendar bridge (child process):** All code is under Go's `internal/`
directory, making it impossible to import from external modules. Must run as
a separate binary, configured via `PCB_*` environment variables.

**rclone (child process):** The WebDAV serve constructor (`newWebDAV`) is
unexported. `rclone serve webdav proton:` is the most reliable path. rclone
is expected to be installed on the system.

### Auth Architecture

Three backends, three different credential stores:

| Backend | API Library | Credential Store |
|---------|------------|------------------|
| Hydroxide | `emersion/go-proton` (v3 API) | `auth.json` (NaCl SecretBox) |
| Calendar bridge | `ProtonMail/go-proton-api` (v4 API) | AES-256-GCM + Argon2id |
| rclone | `rclone/go-proton-api` (fork) | `rclone.conf` (INI, obscured) |

**Mode 1-2:** Each service authenticates independently.

**Mode 3 (unified auth):** The `internal/auth/unified.go` orchestrator takes
username + password + TOTP once and provisions all three credential stores:
1. Hydroxide: calls exported `auth.GeneratePassword()` + `auth.EncryptAndSave()`
2. Calendar: duplicates the AES-GCM store format (or shells out to `--login`)
3. rclone: writes `rclone.conf` section via `rclone obscure`

Since hydroxide uses the legacy v3 API and the calendar bridge uses v4,
unified auth authenticates twice using the same credentials.

### Supervisor Design

The `internal/supervisor/` package manages service lifecycle:

```
Supervisor
├── HydroxideService (embedded)
│   ├── IMAP server goroutine
│   ├── SMTP server goroutine
│   └── CardDAV server goroutine
├── ProcessService: "Calendar Bridge"
│   └── proton-calendar-bridge binary
└── ProcessService: "rclone WebDAV"
    └── rclone serve webdav proton:
```

- `Service` interface: `Start(ctx)`, `Stop(ctx)`, `Info()`, `Healthy(ctx)`
- Health checking via TCP port probes (every 5s by default)
- Graceful shutdown in reverse start order
- Errors are logged but don't stop other services

### GUI Design (Mode 4, planned)

Wails v2 with a Svelte frontend. The Go backend exposes methods via
auto-generated TypeScript bindings:

- `GetServices() []ServiceInfo` — polled by frontend every 1s
- `Login(username, password, totp)` — unified auth
- `RestartService(name)` — individual service control

The frontend renders service cards styled to match Proton Mail Bridge's dark
theme (#1C1B22 background, #6D4AFF accent purple). Each card shows hostname,
port, credentials with copy-to-clipboard buttons.

## Risks and Mitigations

| Risk | Severity | Mitigation |
|------|----------|------------|
| Hydroxide IMAP is experimental | Medium | Known RFC gaps (non-unique UIDs). Works for Thunderbird/mutt. Can swap back to official bridge if needed. |
| Hydroxide uses unofficial Proton API | Medium | Actively maintained (v0.2.31, Jan 2026). MIT licensed. |
| Calendar bridge uses undocumented Proton API endpoints for writes | High | Write path calls `/calendar/v1/{calID}/events` directly. Could break on Proton API changes. |
| Three different auth stores | Low | Unified auth provisions all three. Falls back to separate login per service. |
| rclone not installed on user's system | Low | Mode 2 TUI shows "rclone not found" error for WebDAV; other services still work. |

## Evolution History

1. **v1 — Docker stack**: All bridges in containers behind a unified API server.
   Abandoned — too complex for a desktop app.
2. **v2 — Submodules + GNOME plugin**: Three bridge repos as git submodules.
   GNOME Online Accounts plugin in C for Linux desktop integration. Manual
   build/run instructions.
3. **v3 — Hydroxide pivot (current)**: Replaced proton-mail-bridge with
   hydroxide for pure Go embeddability and added CardDAV. Four-mode progressive
   architecture. Go process supervisor. TUI dashboard with bubbletea.
