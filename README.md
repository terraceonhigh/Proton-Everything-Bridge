# Proton on GNOME Online Accounts

Makes **Proton Mail**, **Proton Drive**, and **Proton Calendar** work with
standard desktop apps through open protocols.

This repo bundles three bridge submodules and a GNOME Online Accounts plugin
that wires them into the desktop.

## Bridges

Each bridge translates one Proton service into an open standard protocol.

| Service | Bridge | Protocol | Default Port |
|---------|--------|----------|-------------|
| Mail | [proton-mail-bridge](proton-mail-bridge/) | IMAP / SMTP | 1143 / 1025 |
| Calendar | [proton-calendar-bridge](proton-calendar-bridge/) | CalDAV | 9842 |
| Drive | [proton-drive-bridge](proton-drive-bridge/) | WebDAV (via rclone) | — |

### Proton Mail Bridge

Official Proton tool. Provides IMAP and SMTP access to your Proton mailbox.

```bash
# Install from https://proton.me/mail/bridge or build from submodule:
cd proton-mail-bridge
make build-nogui
./bridge --cli

# In the CLI:
> login
> info    # note the bridge password
> exit

# Run:
./bridge --noninteractive
# IMAP on :1143, SMTP on :1025
```

### Proton Calendar Bridge

Exposes Proton Calendar as a CalDAV server.

```bash
cd proton-calendar-bridge
go build -o proton-calendar-bridge ./cmd/proton-calendar-bridge/...

# First run — authenticate:
./proton-calendar-bridge --login

# Then run:
./proton-calendar-bridge
# CalDAV on :9842
```

### Proton Drive (via rclone)

rclone has a native Proton Drive backend. Mount or serve over WebDAV.

```bash
# Install rclone: https://rclone.org/install/

# Configure:
rclone config
# → n (new), name it "proton", type "protondrive", follow prompts

# FUSE mount:
rclone mount proton: ~/ProtonDrive --vfs-cache-mode full

# Or serve over WebDAV:
rclone serve webdav proton: --addr 127.0.0.1:9844
```

### Contacts (hydroxide)

[hydroxide](https://github.com/emersion/hydroxide) provides CardDAV access
to Proton contacts. It uses an unofficial API — treat it as experimental.

```bash
go install github.com/emersion/hydroxide/cmd/hydroxide@latest

hydroxide auth user@proton.me
hydroxide carddav
# CardDAV on :8080
```

---

## GNOME Desktop Plugin

A GOA (GNOME Online Accounts) plugin that registers Proton services with
GNOME apps (Evolution, Nautilus, GNOME Calendar).

> Works on **Fedora**, **Ubuntu** (22.04+), **openSUSE**, and **Arch Linux**.

### Install

```bash
bash desktop/install.sh
```

Then open **GNOME Settings → Online Accounts → Proton** to add your account.

The installer will build the bridges from the submodules and install systemd
user services to run them automatically.

### What appears

| App | What you see |
|-----|-------------|
| Evolution / Geary | Proton Mail inbox |
| Files / Nautilus | Proton Drive folder |
| GNOME Calendar | Proton Calendar events |

### Uninstall

```bash
bash desktop/install.sh --uninstall
```

### Building the plugin from source

```bash
sudo apt install meson ninja-build pkg-config \
  libgoa-backend-1.0-dev libglib2.0-dev libsecret-1-dev \
  libsoup-3.0-dev libjson-glib-dev libadwaita-1-dev

cd desktop
meson setup builddir
ninja -C builddir
sudo ninja -C builddir install
```

---

## Architecture

```
            Your Apps
        (any CalDAV/IMAP client)
                |
    ┌───────────┼───────────┐
    │           │           │
  CalDAV      IMAP/SMTP   WebDAV
  proton-     proton-      rclone
  calendar-   mail-        serve
  bridge      bridge       webdav
  :9842       :1143/1025   :9844
    │           │           │
    └───────────┼───────────┘
                │
        Proton API (encrypted)
```

**Design principles:**
- Wrap existing bridges, don't reinvent them
- No new crypto — bridges handle all Proton encryption
- Open standards — CalDAV, CardDAV, WebDAV, IMAP/SMTP

## Documentation

- [Project Design](PROJECT_DESIGN.md) — Architecture and design decisions
- [Build Plan](desktop/MASTER_BUILD_PLAN.md) — GNOME plugin implementation details

## License

GPL-2.0-only — see [LICENSE](LICENSE).
