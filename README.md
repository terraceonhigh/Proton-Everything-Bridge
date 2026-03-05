# Proton on GNOME Online Accounts

Integrates **Proton Mail**, **Proton Drive**, and **Proton Calendar** into
GNOME Online Accounts — providing the same seamless experience as Google or
Microsoft 365 accounts in GNOME.

---

## Install

> Works on **Fedora**, **Ubuntu** (22.04+), and **openSUSE** (Tumbleweed / Leap 15.5+)
> with the GNOME desktop.

Open a terminal and run:

```bash
curl -fsSL https://raw.githubusercontent.com/terraceonhigh/Proton-on-Gnome-Online-Accounts/main/install.sh | bash
```

That's it. The installer handles everything automatically — build tools,
the GOA plugin, Proton Mail Bridge, rclone, and systemd services.

When it finishes, open **GNOME Settings** → **Online Accounts** → **Proton**
to add your account.

> **Tip:** If you prefer to inspect the script first, you can also clone and run it directly:
> ```bash
> git clone --recurse-submodules https://github.com/terraceonhigh/Proton-on-Gnome-Online-Accounts.git
> cd Proton-on-Gnome-Online-Accounts
> bash install.sh
> ```

### After install

| Where | What appears |
|---|---|
| Evolution / Geary (mail app) | Proton Mail inbox |
| Files / Nautilus sidebar | Proton Drive folder |
| GNOME Calendar | Proton Calendar events |

### Something went wrong?

```bash
bash install.sh --status
```

Shows which pieces are installed and which are missing. See
[docs/account-setup-flow.md](docs/account-setup-flow.md#troubleshooting) for
more detail.

### Uninstall

```bash
bash install.sh --uninstall
```

---

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

---

## For Developers

### Building from source

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

### Packaging

Pre-built packaging files are available for:

- **Fedora**: `packaging/fedora/proton-goa.spec`
- **openSUSE**: `packaging/opensuse/proton-goa.spec`
- **Debian/Ubuntu**: `packaging/debian/`
- **Arch Linux**: `packaging/archlinux/PKGBUILD`

### Runtime Dependencies

- **Proton Mail Bridge** — https://proton.me/mail/bridge
- **rclone** — for Proton Drive (`apt install rclone`)
- **proton-calendar-bridge** — built from the included submodule

## Documentation

See [docs/account-setup-flow.md](docs/account-setup-flow.md) for the
account setup guide.

## License

GPL-2.0-only — see [LICENSE](LICENSE).
