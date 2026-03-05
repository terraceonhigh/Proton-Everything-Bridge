# Proton on GNOME Online Accounts

Integrates **Proton Mail**, **Proton Drive**, and **Proton Calendar** into
GNOME Online Accounts — providing the same seamless experience as Google or
Microsoft 365 accounts in GNOME.

## How It Works

This project is a GOA (GNOME Online Accounts) backend plugin that registers
three providers:

| Provider        | Feature  | Backend                          |
|-----------------|----------|----------------------------------|
| Proton Mail     | Mail     | Proton Mail Bridge (IMAP/SMTP)   |
| Proton Drive    | Files    | rclone FUSE mount                |
| Proton Calendar | Calendar | proton-calendar-bridge (CalDAV)  |

All providers connect to **localhost bridges** — no new crypto or direct
Proton API calls. The bridges handle encryption and authentication.

## Building

```bash
# Install dependencies (Debian/Ubuntu)
sudo apt install meson ninja-build pkg-config \
  libgoa-backend-1.0-dev libglib2.0-dev libsecret-1-dev \
  libsoup-3.0-dev libjson-glib-dev

# Build
meson setup builddir
ninja -C builddir

# Install
sudo ninja -C builddir install
```

## Packaging

Pre-built packaging files are available for:

- **Fedora**: `packaging/fedora/proton-goa.spec`
- **openSUSE**: `packaging/opensuse/proton-goa.spec`
- **Debian/Ubuntu**: `packaging/debian/`
- **Arch Linux**: `packaging/archlinux/PKGBUILD`

## Runtime Dependencies

- **Proton Mail Bridge** — https://proton.me/mail/bridge
- **rclone** — for Proton Drive (`apt install rclone`)
- **proton-calendar-bridge** — built from the included submodule

## Documentation

See [docs/account-setup-flow.md](docs/account-setup-flow.md) for the
account setup guide.

## License

GPL-2.0-only — see [LICENSE](LICENSE).
