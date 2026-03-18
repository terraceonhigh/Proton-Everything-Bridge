# Project Design: Proton Services via Open Standards

## Vision

Make Proton services (Mail, Calendar, Contacts, Drive) work with any app on
any device by translating them into open standards: CalDAV, CardDAV, WebDAV,
IMAP/SMTP.

Two delivery modes from one codebase:

- **Server mode**: Docker-based, multi-user, OS-agnostic
- **Desktop mode**: GNOME Online Accounts plugin, single-user, Linux-only

## Core Philosophy

### Maximum Recycling

If a task requires >100 lines of original code, find an existing tool to wrap.
We glue battle-tested bridges together — we don't build new ones.

### No New Crypto

We never implement PGP, SRP, or Proton authentication. The bridges handle all
cryptographic operations. Our code only speaks standard protocols.

### Open Standards First

Every service is exposed via its RFC-defined protocol. No proprietary APIs
leak to clients.

## Component Map

| Service | Protocol | RFC | Bridge | Notes |
|---------|----------|-----|--------|-------|
| Mail | IMAP/SMTP | RFC 3501/5321 | proton-mail-bridge | Official Proton tool |
| Calendar | CalDAV | RFC 4791 | proton-calendar-bridge | Community fork |
| Contacts | CardDAV | RFC 6352 | hydroxide | Unofficial, experimental |
| Files | WebDAV | RFC 4918 | rclone serve webdav | Official rclone backend |
| Discovery | .well-known | RFC 6764 | Caddy routing | Auto-config for clients |

## Server Architecture

### Multi-User Design

Each Proton account gets an isolated set of bridge containers via Docker
Compose project namespacing:

```
docker compose -p user-alice -f docker-compose.user.yml up -d
```

This creates `user-alice-proton-mail-bridge-1`, `user-alice-rclone-webdav-1`,
etc. — each with their own volumes, credentials, and network namespace.

### Routing

A single Caddy instance serves all users. Per-user routes are added
dynamically via Caddy's admin API when accounts are provisioned:

```
/users/alice/caldav/*  → user-alice-proton-calendar-bridge-1:9842
/users/alice/webdav/*  → user-alice-rclone-webdav-1:9844
/users/alice/carddav/* → user-alice-hydroxide-1:8080
```

Path-based routing was chosen over subdomains because:
- Works with a single TLS certificate
- No wildcard DNS needed
- All DAV clients handle arbitrary path prefixes

### Authentication

Two layers:

1. **Gateway auth** (Caddy basicauth): Controls access to the server.
   Set during install, shared across all endpoints.
2. **Bridge auth** (Proton account): Each user's bridges are logged into
   their individual Proton account. Internal only — clients never see
   Proton credentials.

### Dashboard

The web dashboard at `/` is the equivalent of Proton Mail Bridge's window:

- Account list with per-service health indicators
- "Add Account" button to provision new user stacks
- Setup instructions with copy-paste endpoint URLs
- Bridge login commands for Proton authentication

Built with Go + htmx (~550 lines Go, ~120 lines HTML). No npm, no JS
framework, no bundler. Runs as a Docker container alongside Caddy.

### Access Control

Four tiers, configured during install:

| Mode | CIDR ranges | Use case |
|------|------------|----------|
| localhost | `127.0.0.1/32 ::1/128` | Development, single desktop |
| lan | `192.168.0.0/16 10.0.0.0/8 172.16.0.0/12` | Home server |
| whitelist | User-specified | Known devices |
| internet | `0.0.0.0/0 ::/0` | Public server (requires domain) |

### Infrastructure

```
docker-compose.caddy.yml         # Shared: Caddy + dashboard
docker-compose.user.yml          # Per-user: 4 bridge containers
docker-compose.yml               # Legacy single-user (preserved)
Caddyfile                        # Reverse proxy + access control
dashboard/                       # Go + htmx web panel
├── main.go                      # Server + route reconciliation
├── handlers.go                  # HTTP handlers
├── docker.go                    # Docker Compose CLI wrapper
├── caddy.go                     # Caddy admin API client
└── templates/                   # HTML templates (htmx)
containers/                      # Bridge Dockerfiles
├── proton-mail-bridge/
├── proton-calendar-bridge/
├── rclone-webdav/
└── hydroxide/
install-server.sh                # Guided installer
```

## Desktop Architecture (GNOME)

The GNOME plugin registers Proton services as a GOA (GNOME Online Accounts)
provider. Three providers, each wrapping a localhost bridge:

| Provider | Template recycled from | Bridge |
|----------|----------------------|--------|
| Proton Mail | GoaImapSmtpProvider | proton-mail-bridge |
| Proton Drive | GoaOwncloudProvider | rclone FUSE mount |
| Proton Calendar | GoaCalDavProvider | proton-calendar-bridge |

Each provider:
- Checks for its bridge binary at startup
- Hard-codes `127.0.0.1` as the server address
- Registers the appropriate GNOME interface (Mail, Files, Calendar)

See [MASTER_BUILD_PLAN.md](desktop/MASTER_BUILD_PLAN.md) for implementation details.

## Operational Constraints

1. **Maximum Recycling**: Wrap, don't write. CLI tools over libraries.
2. **No New Crypto**: Bridges own all encryption and auth.
3. **GObject Standards**: Follow GNOME C coding style for the desktop plugin.
4. **The Ethiopia Rule**: Prefer architectural stability and clean failure
   states over speed.
5. **4 containers per user**: ~300MB RAM per user stack. Document limits.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| hydroxide uses unofficial Proton API | Marked experimental; opt-in via Docker profile |
| proton-mail-bridge requires interactive login | Dashboard shows CLI commands; future: web terminal |
| Caddy routes lost on restart | Dashboard reconciles on startup |
| Docker socket access in dashboard | Mounted read-only; only runs compose commands |
| 4 containers per user (resource intensive) | Dashboard shows resource info; document minimums |
| Bridge credential format changes | Version-guard parsing; fall back to UI prompt |
