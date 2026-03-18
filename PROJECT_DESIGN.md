# Project Design: Proton Services via Open Standards

## Vision

Make Proton services (Mail, Calendar, Drive) work with any app by
translating them into open standards: CalDAV, WebDAV, IMAP/SMTP.

## Core Philosophy

### Maximum Recycling

Wrap battle-tested bridges — don't build new ones. If a task requires
>100 lines of original code, find an existing tool to wrap.

### No New Crypto

We never implement PGP, SRP, or Proton authentication. The bridges handle
all cryptographic operations. Our code only speaks standard protocols.

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

### Structure

```
desktop/
├── src/goabackend/              # GOA provider C source
├── data/                        # systemd user services
├── packaging/                   # Distro packaging (Arch, Debian, Fedora, openSUSE)
├── meson.build                  # Build system
└── install.sh                   # Desktop installer
```

See [MASTER_BUILD_PLAN.md](desktop/MASTER_BUILD_PLAN.md) for implementation details.

## Operational Constraints

1. **Maximum Recycling**: Wrap, don't write. CLI tools over libraries.
2. **No New Crypto**: Bridges own all encryption and auth.
3. **GObject Standards**: Follow GNOME C coding style for the desktop plugin.

## Risks and Mitigations

| Risk | Mitigation |
|------|------------|
| hydroxide uses unofficial Proton API | Marked experimental; documented as optional |
| proton-mail-bridge requires interactive login | Documented in README |
| Bridge credential format changes | Version-guard parsing; fall back to prompts |
