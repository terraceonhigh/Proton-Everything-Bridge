# Proton on GNOME Online Accounts

Integrates **Proton Mail**, **Proton Drive**, and **Proton Calendar** into
GNOME Online Accounts — providing the same seamless experience as Google or
Microsoft 365 accounts in GNOME.

---

## Quick Start

> Works on **Fedora**, **Ubuntu** (22.04+), and **openSUSE** (Tumbleweed / Leap 15.5+)
> with the GNOME desktop.

### What you need

| Requirement | Notes |
|---|---|
| A Linux PC with GNOME | Fedora, Ubuntu, or openSUSE |
| A Proton account | Free at [proton.me](https://proton.me) |
| Internet connection | For downloading packages |
| ~15 minutes | Most of it is waiting for downloads |

### Step 1 — Open a Terminal

A Terminal is a text window where you type commands — like a chat box for your computer.

- **Fedora / Ubuntu / openSUSE**: press **Ctrl + Alt + T**
- If that doesn't work: right-click an empty spot on the desktop and choose **Open Terminal**, or search for "Terminal" in your apps menu.

A black (or dark) window will appear. That's the Terminal — leave it open.

### Step 2 — Run the installer

Click inside the Terminal, paste the command below, and press **Enter**:

```bash
git clone https://github.com/terraceonhigh/Proton-on-Gnome-Online-Accounts.git && cd Proton-on-Gnome-Online-Accounts && bash install.sh
```

The installer will:
- Ask for your **computer password** — this is normal and safe (same as installing any app)
- Download and install all the required pieces automatically
- Walk you through the one step that needs your Proton login

> **Tip:** if you see a password prompt, type your password and press Enter — the
> characters will not appear on screen; that is normal.

### Step 3 — Install Proton Mail Bridge

The installer will pause and ask you to install Proton Mail Bridge separately
(it needs your Proton account credentials, so it cannot be installed fully
automatically).

1. Go to **[proton.me/mail/bridge](https://proton.me/mail/bridge)**
2. Download the package for your distro (`.rpm` for Fedora/openSUSE, `.deb` for Ubuntu)
3. Double-click the downloaded file — your software centre will open and install it
4. Launch **Proton Mail Bridge** from your applications menu and sign in

When Proton Mail Bridge is running, go back to the Terminal and press **Enter**
to continue.

### Step 4 — Add your Proton account in GNOME Settings

1. Open **GNOME Settings**
2. Click **Online Accounts**
3. Click the **Proton** option and follow the prompts

That's it! After a moment you will see:

| Where | What appears |
|---|---|
| Evolution / Geary (mail app) | Proton Mail inbox |
| Files / Nautilus sidebar | Proton Drive folder |
| GNOME Calendar | Proton Calendar events |

### Something went wrong?

Run the status checker:
```bash
bash install.sh --status
```

It will show which pieces are installed and which are missing.

For more detail see [docs/account-setup-flow.md](docs/account-setup-flow.md#troubleshooting).

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
