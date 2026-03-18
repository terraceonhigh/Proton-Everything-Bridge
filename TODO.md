# TODO

## GNOME Online Accounts Plugin

A GOA (GNOME Online Accounts) plugin lives in `desktop/` that registers Proton
services with GNOME apps (Evolution, Nautilus, GNOME Calendar). This is a
separate workstream from the main bridge app and is not yet integrated with the
new hydroxide-based architecture.

### Current State

The plugin is **code-complete but untested** against the new bridge stack. It
was written for the original submodule architecture (proton-mail-bridge,
separate hydroxide CLI, rclone FUSE mount) and needs updating to work with the
unified Proton Everything Bridge.

### What Exists

- **GOA provider plugins** in C (`desktop/src/goabackend/`):
  - `goaprotonmailprovider.c` — Mail provider (IMAP/SMTP on localhost)
  - `goaprotoncalendarprovider.c` — Calendar provider (CalDAV on localhost)
  - `goaprotondriveprovider.c` — Drive provider (rclone FUSE mount)
  - `goaprotonauth.c` — Helper utilities for bridge discovery and health checks
- **Build system**: meson (`desktop/meson.build`)
- **Systemd user services** (`desktop/data/`):
  - `protonmail-bridge.service`
  - `proton-calendar-bridge.service`
  - `proton-drive-bridge@.service` (template for rclone mount instances)
- **Installer/uninstaller** scripts (`desktop/install.sh`, `desktop/uninstall.sh`)
- **Distribution packaging** (`desktop/packaging/`):
  - Debian (control, rules, changelog)
  - Fedora (spec file)
  - openSUSE (spec + service file)
  - Arch Linux (PKGBUILD)
- **Implementation roadmap**: `desktop/MASTER_BUILD_PLAN.md`

### What Needs to Happen

- [ ] Update systemd services to start the unified bridge (proton-bridge-tui or
      proton-everything-bridge) instead of individual bridge binaries
- [ ] Update the mail provider to point at hydroxide's IMAP/SMTP ports instead
      of proton-mail-bridge
- [ ] Add a CardDAV/Contacts provider (hydroxide now provides CardDAV, which
      the original plugin didn't cover)
- [ ] Update the drive provider to use WebDAV (rclone serve) instead of FUSE
      mount, or support both
- [ ] Test the plugin on Fedora, Ubuntu, openSUSE, and Arch with the new stack
- [ ] Update the installer script to build/install the unified bridge binary
- [ ] Update distribution packaging to depend on the unified bridge

### Supported Platforms

The GNOME plugin only works on Linux distributions with GNOME 42+ and GOA
support:
- Fedora
- Ubuntu 22.04+
- openSUSE
- Arch Linux

### Dependencies

```
meson >= 0.62
goa-backend-1.0
glib-2.0, gobject-2.0, gio-2.0
libsecret-1
libsoup-3.0
json-glib-1.0
libadwaita-1
```

### Building (standalone, for development)

```bash
cd desktop
meson setup builddir
ninja -C builddir
sudo ninja -C builddir install
```

---

## Unified Auth (Mode 3)

- [ ] Implement go-proton-api authentication call for calendar bridge
      credential provisioning (currently a placeholder in `internal/auth/unified.go`)
- [ ] Match the calendar bridge's argon2id key derivation for full
      interoperability with its native session store (currently using
      HMAC-SHA256 KDF which writes a separate format)
- [ ] Test unified login flow end-to-end with a real Proton account

## GUI (Mode 4)

- [ ] Initialize Wails v2 project in `cmd/proton-everything-bridge/`
- [ ] Build Svelte frontend with service cards matching Proton dark theme
- [ ] Implement system tray (via `getlantern/systray` or Wails v3 native)
- [ ] Wire up Go backend bindings (supervisor + auth)
- [ ] Test on macOS and Linux

## General

- [ ] Add CLI flags to proton-bridge-tui for port/config overrides
- [ ] Add TOML config file support (`~/.config/proton-everything-bridge/config.toml`)
- [ ] Improve IMAP reliability (hydroxide's IMAP is experimental, has known
      RFC compliance gaps with non-unique UIDs)
- [ ] Add automatic service restart on crash in the supervisor
- [ ] Add log file rotation
