#!/usr/bin/env bash
# install.sh — Proton on GNOME Online Accounts — one-shot installer
#
# Supported distributions:
#   • Fedora 38+
#   • Ubuntu 22.04+ / Debian 12+
#   • openSUSE Tumbleweed / Leap 15.5+
#
# Usage:
#   bash install.sh           — full install
#   bash install.sh --status  — check what is/isn't installed

set -euo pipefail

# ── Colours ───────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

info() { printf "  ${BLUE}→${NC}  %s\n"      "$*"; }
ok()   { printf "  ${GREEN}✓${NC}  %s\n"      "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n"     "$*"; }
step() { printf "\n${BOLD}━━  %s${NC}\n"      "$*"; }
die()  { printf "\n  ${RED}✗  ERROR:${NC} %s\n\n" "$*" >&2; exit 1; }

# ── Parse arguments ───────────────────────────────────────────────────────────
STATUS_ONLY=0
[[ "${1:-}" == "--status" ]] && STATUS_ONLY=1

# ── Detect distro ─────────────────────────────────────────────────────────────
[ -f /etc/os-release ] || die "Cannot detect your Linux distribution."
# shellcheck source=/dev/null
source /etc/os-release
DISTRO_ID="${ID:-unknown}"
DISTRO_LIKE="${ID_LIKE:-}"

is_fedora()   { [[ "$DISTRO_ID" == fedora ]]; }
is_ubuntu()   { [[ "$DISTRO_ID" == ubuntu || "$DISTRO_ID" == debian  \
                  || "$DISTRO_LIKE" == *debian* || "$DISTRO_LIKE" == *ubuntu* ]]; }
is_opensuse() { [[ "$DISTRO_ID" == opensuse-tumbleweed || "$DISTRO_ID" == opensuse-leap \
                  || "$DISTRO_ID" == suse || "$DISTRO_LIKE" == *suse* ]]; }

if   is_fedora;   then DISTRO_LABEL="Fedora"
elif is_ubuntu;   then DISTRO_LABEL="Ubuntu / Debian"
elif is_opensuse; then DISTRO_LABEL="openSUSE"
else die "Your distribution ($DISTRO_ID) is not supported yet.
         Supported: Fedora, Ubuntu/Debian, openSUSE."
fi

# ── Repo root (works whether run via 'bash install.sh' or './install.sh') ─────
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ─────────────────────────────────────────────────────────────────────────────
# STATUS MODE — just check what's present and exit
# ─────────────────────────────────────────────────────────────────────────────
if [[ $STATUS_ONLY -eq 1 ]]; then
  printf "\n${BOLD}Proton on GNOME Online Accounts — status check${NC}\n\n"
  printf "  Distribution : %s\n\n" "$DISTRO_LABEL"

  _check() {
    local label="$1"; shift
    if command -v "$1" &>/dev/null || ([ "${2:-}" == "file" ] && [ -e "$1" ]); then
      printf "  ${GREEN}✓${NC}  %-30s %s\n" "$label" "$(command -v "$1" 2>/dev/null || echo "$1")"
    else
      printf "  ${RED}✗${NC}  %-30s not found\n" "$label"
    fi
  }
  _check "meson"                   meson
  _check "ninja"                   ninja
  _check "pkg-config"              pkg-config
  _check "rclone"                  rclone
  _check "go (for cal-bridge)"     go
  _check "protonmail-bridge"       protonmail-bridge
  _check "proton-calendar-bridge"  proton-calendar-bridge
  _check "GOA plugin (.so)"        /usr/lib/gnome-online-accounts/goa-proton.so file
  _check "GOA plugin (lib64)"      /usr/lib64/gnome-online-accounts/goa-proton.so file
  printf "\n"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# FULL INSTALL
# ─────────────────────────────────────────────────────────────────────────────
clear
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║       Proton  ▶  GNOME Online Accounts  —  Installer         ║
╚══════════════════════════════════════════════════════════════╝${NC}

  This script will:
    1.  Install all required software (needs internet + your password)
    2.  Build and install the Proton GOA plugin
    3.  Register background services with systemd
    4.  Guide you through the remaining manual steps

  Distribution detected: ${BOLD}${DISTRO_LABEL}${NC}

  Your computer password (sudo) will be asked once — that is normal,
  the same as when you install any app.

"
read -rp "  Press Enter to start, or Ctrl+C to cancel: "

# ── Step 1: Install build dependencies ───────────────────────────────────────
step "Step 1 / 5 — Installing build tools and libraries"
info "Talking to your distro's package manager — please wait..."

if is_fedora; then
  sudo dnf install -y \
    meson ninja-build gcc pkg-config git \
    gnome-online-accounts-devel \
    glib2-devel libsecret-devel \
    libsoup3-devel json-glib-devel \
    rclone golang \
    fuse3

elif is_ubuntu; then
  # Make sure universe is enabled (needed for rclone on some Ubuntu releases)
  if command -v add-apt-repository &>/dev/null; then
    sudo add-apt-repository -y universe 2>/dev/null || true
  fi
  sudo apt-get update -qq
  sudo apt-get install -y \
    meson ninja-build gcc pkg-config git \
    libgoa-backend-1.0-dev \
    libglib2.0-dev libsecret-1-dev \
    libsoup-3.0-dev libjson-glib-dev \
    rclone golang-go \
    fuse3

elif is_opensuse; then
  sudo zypper --non-interactive install \
    meson ninja gcc pkg-config git \
    gnome-online-accounts-devel \
    glib2-devel libsecret-devel \
    libsoup3-devel libjson-glib-devel \
    rclone go \
    fuse3
fi

ok "Build tools and libraries installed"

# ── Step 2: Build + install the GOA plugin ────────────────────────────────────
step "Step 2 / 5 — Building the Proton GOA plugin"

# Initialise git submodules (contains bridge source code)
if [ -d "$REPO_DIR/.git" ] && [ -f "$REPO_DIR/.gitmodules" ]; then
  info "Fetching bridge source code (submodules)..."
  git -C "$REPO_DIR" submodule update --init --recursive 2>&1 \
    | grep -v '^$' | sed 's/^/    /' || warn "Submodule fetch had warnings — continuing"
  ok "Bridge source code ready"
else
  warn "This is not a full git clone — bridge submodules will not be available."
  warn "Tip: clone with:  git clone --recurse-submodules <repo-url>"
fi

info "Compiling the plugin..."
BUILD_DIR="$REPO_DIR/_build"
rm -rf "$BUILD_DIR"
meson setup "$BUILD_DIR" --prefix=/usr --buildtype=release
ninja -C "$BUILD_DIR"
ok "Plugin compiled"

info "Installing the plugin (needs sudo)..."
sudo ninja -C "$BUILD_DIR" install
ok "Plugin installed"

# ── Step 3: Build proton-calendar-bridge ──────────────────────────────────────
step "Step 3 / 5 — Building Proton Calendar Bridge"
CAL_SRC="$REPO_DIR/proton-calendar-bridge"

if [ -d "$CAL_SRC" ] && [ -n "$(ls -A "$CAL_SRC" 2>/dev/null)" ]; then
  if command -v go &>/dev/null; then
    info "Building proton-calendar-bridge..."
    GOBIN_OUT="$CAL_SRC/proton-calendar-bridge"
    ( cd "$CAL_SRC" && go build -o proton-calendar-bridge ./cmd/proton-calendar-bridge/... 2>&1 \
        | sed 's/^/    /' ) || die "Build of proton-calendar-bridge failed.
    Check the output above for details."
    sudo cp "$GOBIN_OUT" /usr/local/bin/proton-calendar-bridge
    sudo chmod 755 /usr/local/bin/proton-calendar-bridge
    ok "proton-calendar-bridge installed to /usr/local/bin/"
  else
    warn "Go compiler not found — skipping proton-calendar-bridge."
    warn "Calendar sync will not work until you build it manually."
  fi
else
  warn "proton-calendar-bridge submodule is empty — skipping."
  warn "If you cloned without --recurse-submodules, run:"
  warn "  git submodule update --init --recursive"
fi

# ── Step 4: Register systemd user services ────────────────────────────────────
step "Step 4 / 5 — Registering background services"
info "Reloading systemd user daemon..."
systemctl --user daemon-reload

for svc in protonmail-bridge.service proton-calendar-bridge.service; do
  if systemctl --user list-unit-files "$svc" &>/dev/null; then
    systemctl --user enable "$svc" 2>/dev/null || true
    ok "Enabled $svc (will start automatically after you install its bridge)"
  fi
done
ok "Services registered"

# ── Step 5: Proton Mail Bridge (manual) ───────────────────────────────────────
step "Step 5 / 5 — Install Proton Mail Bridge"

if is_fedora; then PKG_TYPE=".rpm (RPM package)"
elif is_ubuntu; then PKG_TYPE=".deb (Debian package)"
else PKG_TYPE=".rpm (RPM package)"
fi

printf "
  Proton Mail Bridge needs to be installed separately because it
  requires you to sign in to your Proton account during setup.

  ┌──────────────────────────────────────────────────────────────┐
  │                                                              │
  │  1. Open this link in a browser:                            │
  │       https://proton.me/mail/bridge                         │
  │                                                              │
  │  2. Download the %-36s│
  │                                                              │
  │  3. Double-click the downloaded file to install it.         │
  │                                                              │
  │  4. Open Proton Mail Bridge from your applications menu     │
  │     and sign in with your Proton account.                   │
  │                                                              │
  └──────────────────────────────────────────────────────────────┘

" "$PKG_TYPE"

read -rp "  Once Proton Mail Bridge is installed and running, press Enter: "

# Try to start the bridge service now
if systemctl --user list-unit-files protonmail-bridge.service &>/dev/null; then
  if command -v protonmail-bridge &>/dev/null; then
    systemctl --user start protonmail-bridge.service 2>/dev/null \
      && ok "protonmail-bridge service started" \
      || warn "Could not start protonmail-bridge.service — you can start it later with:\n\n    systemctl --user start protonmail-bridge"
  else
    warn "protonmail-bridge binary not found yet."
    warn "After installing it, start the service with:"
    printf "    systemctl --user start protonmail-bridge\n\n"
  fi
fi

if command -v proton-calendar-bridge &>/dev/null; then
  systemctl --user start proton-calendar-bridge.service 2>/dev/null \
    && ok "proton-calendar-bridge service started" \
    || warn "Could not start proton-calendar-bridge.service automatically."
fi

# ── Final summary ─────────────────────────────────────────────────────────────
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║                      All done!                               ║
╚══════════════════════════════════════════════════════════════╝${NC}

  ${BOLD}To finish setup:${NC}

    1.  Make sure Proton Mail Bridge is installed and you are signed
        in (see Step 5 above if you haven't done this yet).

    2.  Open ${BOLD}GNOME Settings${NC}  →  ${BOLD}Online Accounts${NC}
        and click the Proton option to add your account.

    3.  Done!  Your Proton Mail appears in Evolution / Geary,
        Proton Drive appears in the Files app (Nautilus sidebar),
        and your calendars appear in GNOME Calendar.

  ${BOLD}Useful commands:${NC}
    Check service status :  bash install.sh --status
    View mail bridge logs:  journalctl --user -u protonmail-bridge -f
    View cal bridge logs :  journalctl --user -u proton-calendar-bridge -f

"
