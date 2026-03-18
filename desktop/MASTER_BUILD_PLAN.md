# GNOME Plugin Build Plan

This document covers the **desktop mode** — the GNOME Online Accounts plugin.
For the server architecture, see [PROJECT_DESIGN.md](../PROJECT_DESIGN.md).

## Overview

The plugin registers three GOA providers that connect to localhost bridges.
Each provider recycles an existing upstream GOA provider as its template.

## Providers

### A. Proton Mail (IMAP/SMTP)

| | |
|---|---|
| **Template** | `GoaImapSmtpProvider` |
| **Files** | `src/goabackend/goaprotonmailprovider.{c,h}`, `goaprotonbridge.{c,h}` |
| **Bridge** | proton-mail-bridge (official) |
| **Strategy** | Clone IMAP provider, hard-code `127.0.0.1`, scrape bridge for ports + app password |

Key constants:
```c
#define GOA_PROTON_MAIL_NAME       "proton_mail"
#define GOA_PROTON_MAIL_IMAP_HOST  "127.0.0.1"
#define GOA_PROTON_MAIL_SMTP_HOST  "127.0.0.1"
```

The bridge helper (`goaprotonbridge.c`) runs `protonmail-bridge --cli` and
parses output for dynamic IMAP port, SMTP port, and generated app-password.

### B. Proton Drive (WebDAV/FUSE)

| | |
|---|---|
| **Template** | `GoaOwncloudProvider` (via `GoaWebDavProvider`) |
| **Files** | `src/goabackend/goaprotondriveprovider.{c,h}`, `goaprotonrclone.{c,h}` |
| **Bridge** | rclone FUSE mount |
| **Strategy** | Replace Nextcloud Login Flow with rclone config, expose mount at `~/ProtonDrive` |

Key constants:
```c
#define GOA_PROTON_DRIVE_NAME          "proton_drive"
#define GOA_PROTON_DRIVE_MOUNT_POINT   "ProtonDrive"
#define GOA_PROTON_DRIVE_RCLONE_REMOTE "proton"
```

The rclone helper (`goaprotonrclone.c`) manages `rclone config create` and
`rclone mount`, storing credentials in GNOME Keyring via `libsecret`.

### C. Proton Calendar (CalDAV)

| | |
|---|---|
| **Template** | `GoaCalDavProvider` |
| **Files** | `src/goabackend/goaprotoncalendarprovider.{c,h}` |
| **Bridge** | proton-calendar-bridge (community) |
| **Strategy** | Point CalDAV at `http://127.0.0.1:9842/caldav/`, verify with PROPFIND |

Key constants:
```c
#define GOA_PROTON_CALENDAR_NAME       "proton_calendar"
#define GOA_PROTON_CALENDAR_CALDAV_URI "http://127.0.0.1:9842/caldav/"
```

## Files to Create/Modify

| File | Action |
|------|--------|
| `src/goabackend/goaprotonmailprovider.{c,h}` | CREATE |
| `src/goabackend/goaprotonbridge.{c,h}` | CREATE |
| `src/goabackend/goaprotondriveprovider.{c,h}` | CREATE |
| `src/goabackend/goaprotonrclone.{c,h}` | CREATE |
| `src/goabackend/goaprotoncalendarprovider.{c,h}` | CREATE |
| `src/goabackend/meson.build` | MODIFY — add new sources |
| `src/goabackend/goabackend.h` | MODIFY — add includes |

## Build

```bash
# Dependencies (Debian/Ubuntu)
sudo apt install meson ninja-build pkg-config \
  libgoa-backend-1.0-dev libglib2.0-dev libsecret-1-dev \
  libsoup-3.0-dev libjson-glib-dev libadwaita-1-dev

# Build
meson setup builddir
ninja -C builddir
sudo ninja -C builddir install
```

## Runtime Dependencies

| Dependency | Required for | Install |
|------------|-------------|---------|
| proton-mail-bridge | Mail provider | https://proton.me/mail/bridge |
| rclone | Drive provider | `apt install rclone` |
| proton-calendar-bridge | Calendar provider | Built from submodule |

## Implementation Order

1. `goaprotonbridge.{c,h}` — bridge helper
2. `goaprotonmailprovider.{c,h}` — mail provider (validates build chain)
3. `goaprotonrclone.{c,h}` — rclone helper
4. `goaprotondriveprovider.{c,h}` — drive provider
5. `goaprotoncalendarprovider.{c,h}` — calendar provider
6. Meson + header integration

## Risks

| Risk | Mitigation |
|------|------------|
| Bridge CLI output format changes | Parse with regex; version guard; fall back to UI prompt |
| rclone not installed | Check in `add_account()`; show `GtkAlertDialog` |
| Calendar write support incomplete | Ship read-only first; enable write when bridge supports it |
| GOA API changes between versions | Pin to GOA 3.50.4; test on target distros |
