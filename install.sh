#!/usr/bin/env bash
# install.sh — Proton on GNOME Online Accounts — one-command installer
#
# Supported distributions:
#   • Fedora 38+
#   • Ubuntu 22.04+ / Debian 12+
#   • openSUSE Tumbleweed / Leap 15.5+
#
# Usage:
#   bash install.sh              — full install (everything automatic)
#   bash install.sh --status     — check what is/isn't installed
#   bash install.sh --no-bridge  — install without downloading Proton Mail Bridge
#   bash install.sh --uninstall  — remove everything this script installed
#
# Can also be run via:
#   curl -fsSL https://raw.githubusercontent.com/terraceonhigh/Proton-on-Gnome-Online-Accounts/main/install.sh | bash

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

# ── Parse arguments ──────────────────────────────────────────────────────────
STATUS_ONLY=0
SKIP_BRIDGE=0
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --status)    STATUS_ONLY=1 ;;
    --no-bridge) SKIP_BRIDGE=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --help|-h)
      printf "Usage: bash install.sh [OPTIONS]\n\n"
      printf "Options:\n"
      printf "  --status      Check what is/isn't installed\n"
      printf "  --no-bridge   Skip Proton Mail Bridge download\n"
      printf "  --uninstall   Remove everything this script installed\n"
      printf "  --help        Show this help\n"
      exit 0
      ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

# ── Detect distro ────────────────────────────────────────────────────────────
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

# ── Helper: find GOA plugin path ─────────────────────────────────────────────
find_goa_plugin() {
  for p in /usr/lib64/gnome-online-accounts/goa-proton.so \
           /usr/lib/gnome-online-accounts/goa-proton.so; do
    if [ -e "$p" ]; then echo "$p"; return 0; fi
  done
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
# STATUS MODE
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
# UNINSTALL MODE
# ─────────────────────────────────────────────────────────────────────────────
if [[ $UNINSTALL -eq 1 ]]; then
  printf "\n${BOLD}Proton on GNOME Online Accounts — uninstall${NC}\n\n"

  # Stop and disable proton-drive-bridge instances
  DRIVE_INSTANCES=$(systemctl --user list-units --no-legend --plain \
    'proton-drive-bridge@*' 2>/dev/null | awk '{print $1}' || true)
  if [ -n "$DRIVE_INSTANCES" ]; then
    while IFS= read -r instance; do
      systemctl --user stop "$instance" 2>/dev/null && ok "Stopped $instance" || true
    done <<< "$DRIVE_INSTANCES"
  fi
  if mountpoint -q "$HOME/ProtonDrive" 2>/dev/null; then
    fusermount -u "$HOME/ProtonDrive" 2>/dev/null && ok "Unmounted ~/ProtonDrive" || true
  fi
  systemctl --user disable 'proton-drive-bridge@.service' 2>/dev/null || true

  # Stop and disable remaining services
  for svc in protonmail-bridge.service proton-calendar-bridge.service; do
    if systemctl --user is-active "$svc" &>/dev/null; then
      systemctl --user stop "$svc" 2>/dev/null && ok "Stopped $svc"
    fi
    if systemctl --user is-enabled "$svc" &>/dev/null; then
      systemctl --user disable "$svc" 2>/dev/null && ok "Disabled $svc"
    fi
  done

  # Remove GOA plugin
  for p in /usr/lib64/gnome-online-accounts/goa-proton.so \
           /usr/lib/gnome-online-accounts/goa-proton.so; do
    if [ -e "$p" ]; then
      sudo rm -f "$p" && ok "Removed $p"
    fi
  done

  # Remove calendar bridge
  if [ -e /usr/local/bin/proton-calendar-bridge ]; then
    sudo rm -f /usr/local/bin/proton-calendar-bridge && ok "Removed proton-calendar-bridge"
  fi

  # Remove systemd unit files
  UNIT_DIR="/usr/lib/systemd/user"
  for unit in protonmail-bridge.service proton-calendar-bridge.service "proton-drive-bridge@.service"; do
    if [ -e "$UNIT_DIR/$unit" ]; then
      sudo rm -f "$UNIT_DIR/$unit" && ok "Removed $UNIT_DIR/$unit"
    fi
  done

  systemctl --user daemon-reload 2>/dev/null || true
  printf "\n  ${GREEN}Done.${NC} Proton Mail Bridge (if installed via your package manager)\n"
  printf "  can be removed with your distro's package manager.\n\n"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# FULL INSTALL
# ─────────────────────────────────────────────────────────────────────────────

# Determine how we got here — inside a git clone, or piped from curl?
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}" 2>/dev/null)" 2>/dev/null && pwd 2>/dev/null || echo "")"
CLONED_TEMP=""

if [ -n "$SCRIPT_DIR" ] && [ -d "$SCRIPT_DIR/.git" ] && [ -f "$SCRIPT_DIR/meson.build" ]; then
  REPO_DIR="$SCRIPT_DIR"
else
  # Running via curl-pipe-bash or from outside the repo — clone into a temp dir
  CLONED_TEMP="$(mktemp -d)"
  REPO_DIR="$CLONED_TEMP/Proton-on-Gnome-Online-Accounts"
fi

# Cleanup temp dir on exit if we created one
cleanup() {
  if [ -n "$CLONED_TEMP" ] && [ -d "$CLONED_TEMP" ]; then
    rm -rf "$CLONED_TEMP"
  fi
}
trap cleanup EXIT

TOTAL_STEPS=4
if [[ $SKIP_BRIDGE -eq 1 ]]; then
  BRIDGE_STEP="skip"
else
  BRIDGE_STEP="auto"
fi

clear
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║       Proton  ▶  GNOME Online Accounts  —  Installer         ║
╚══════════════════════════════════════════════════════════════╝${NC}

  This script will automatically:
    1.  Install all required software
    2.  Build and install the Proton GOA plugin
    3.  Download and install Proton Mail Bridge
    4.  Register background services

  Distribution detected: ${BOLD}${DISTRO_LABEL}${NC}

  Your computer password (sudo) will be asked — that is normal,
  the same as when you install any app.

"

# ── Step 1: Install build dependencies ───────────────────────────────────────
step "Step 1 / $TOTAL_STEPS — Installing build tools and libraries"
info "Talking to your distro's package manager — please wait..."

if is_fedora; then
  sudo dnf install -y \
    meson ninja-build gcc pkg-config git curl \
    gnome-online-accounts-devel \
    glib2-devel libsecret-devel \
    libsoup3-devel json-glib-devel \
    rclone golang \
    fuse3

elif is_ubuntu; then
  if command -v add-apt-repository &>/dev/null; then
    sudo add-apt-repository -y universe 2>/dev/null || true
  fi
  sudo apt-get update -qq
  sudo apt-get install -y \
    meson ninja-build gcc pkg-config git curl \
    libgoa-backend-1.0-dev \
    libglib2.0-dev libsecret-1-dev \
    libsoup-3.0-dev libjson-glib-dev \
    rclone golang-go \
    fuse3

elif is_opensuse; then
  sudo zypper --non-interactive install \
    meson ninja gcc pkg-config git curl \
    gnome-online-accounts-devel \
    glib2-devel libsecret-devel \
    libsoup3-devel libjson-glib-devel \
    rclone go \
    fuse3
fi

ok "Build tools and libraries installed"

# ── Step 2: Build + install the GOA plugin ───────────────────────────────────
step "Step 2 / $TOTAL_STEPS — Building the Proton GOA plugin"

# If we need to clone the repo (curl-pipe-bash mode), do it now
if [ -n "$CLONED_TEMP" ]; then
  info "Downloading source code..."
  git clone --recurse-submodules --depth 1 \
    https://github.com/terraceonhigh/Proton-on-Gnome-Online-Accounts.git \
    "$REPO_DIR" 2>&1 | sed 's/^/    /'
  ok "Source code downloaded"
else
  # Initialise git submodules if inside a git clone
  if [ -d "$REPO_DIR/.git" ] && [ -f "$REPO_DIR/.gitmodules" ]; then
    info "Fetching bridge source code (submodules)..."
    git -C "$REPO_DIR" submodule update --init --recursive 2>&1 \
      | grep -v '^$' | sed 's/^/    /' || warn "Submodule fetch had warnings — continuing"
    ok "Bridge source code ready"
  fi
fi

info "Compiling the plugin..."
BUILD_DIR="$REPO_DIR/_build"
rm -rf "$BUILD_DIR"
meson setup "$BUILD_DIR" "$REPO_DIR" --prefix=/usr --buildtype=release
ninja -C "$BUILD_DIR"
ok "Plugin compiled"

info "Installing the plugin (needs sudo)..."
sudo ninja -C "$BUILD_DIR" install
ok "Plugin installed"

# Verify plugin was installed correctly
info "Verifying plugin installation..."
GOA_PLUGIN_PATH=""
for p in /usr/lib64/gnome-online-accounts/goa-proton.so \
         /usr/lib/gnome-online-accounts/goa-proton.so; do
  if [ -e "$p" ]; then GOA_PLUGIN_PATH="$p"; break; fi
done
if [ -n "$GOA_PLUGIN_PATH" ]; then
  if ldd "$GOA_PLUGIN_PATH" 2>&1 | grep -q "not found"; then
    warn "Plugin installed but has missing library dependencies:"
    ldd "$GOA_PLUGIN_PATH" 2>&1 | grep "not found" | sed 's/^/    /'
  else
    ok "Plugin verified at $GOA_PLUGIN_PATH — all dependencies satisfied"
  fi
else
  warn "Plugin .so not found at expected locations — GOA may not discover the providers."
fi

# Build proton-calendar-bridge if submodule is available and valid
CAL_SRC="$REPO_DIR/proton-calendar-bridge"
if [ -d "$CAL_SRC" ] && [ -n "$(ls -A "$CAL_SRC" 2>/dev/null)" ]; then
  if [ ! -f "$CAL_SRC/go.mod" ]; then
    warn "proton-calendar-bridge submodule present but missing go.mod — skipping build."
  elif ! command -v go &>/dev/null; then
    warn "Go compiler not found — skipping proton-calendar-bridge."
  else
    info "Building proton-calendar-bridge..."
    ( cd "$CAL_SRC" && go build -o proton-calendar-bridge ./cmd/proton-calendar-bridge/... 2>&1 \
        | sed 's/^/    /' ) || warn "proton-calendar-bridge build failed — calendar sync will not work until you build it manually."
    if [ -f "$CAL_SRC/proton-calendar-bridge" ]; then
      sudo cp "$CAL_SRC/proton-calendar-bridge" /usr/local/bin/proton-calendar-bridge
      sudo chmod 755 /usr/local/bin/proton-calendar-bridge
      ok "proton-calendar-bridge installed to /usr/local/bin/"
    fi
  fi
elif [ -d "$CAL_SRC" ]; then
  warn "proton-calendar-bridge submodule is empty — calendar integration unavailable."
  warn "If you need calendar support, run: git submodule update --init --recursive"
fi

# Configure rclone Proton Drive remote
if command -v rclone &>/dev/null; then
  info "Checking rclone Proton Drive remote..."
  if rclone listremotes 2>/dev/null | grep -q "^proton:$"; then
    ok "rclone 'proton:' remote already configured"
  else
    info "Creating rclone 'proton:' remote..."
    rclone config create proton protondrive 2>/dev/null \
      && ok "rclone 'proton:' remote created" \
      || warn "Could not auto-create rclone remote — run 'rclone config' manually to set up a 'proton:' remote."
  fi
  mkdir -p "$HOME/ProtonDrive"
  ok "Proton Drive mount point ready at ~/ProtonDrive"
fi

# ── Step 3: Install Proton Mail Bridge ───────────────────────────────────────
step "Step 3 / $TOTAL_STEPS — Installing Proton Mail Bridge"

if [[ "$BRIDGE_STEP" == "skip" ]]; then
  info "Skipping (--no-bridge flag was used)"
elif command -v protonmail-bridge &>/dev/null; then
  ok "Proton Mail Bridge is already installed"
else
  info "Downloading Proton Mail Bridge..."

  BRIDGE_DL_DIR="$(mktemp -d)"
  BRIDGE_OK=0

  # Proton publishes stable bridge packages at these URLs.
  # The /download/bridge/linux endpoint redirects to the latest version.
  if is_fedora || is_opensuse; then
    BRIDGE_PKG="$BRIDGE_DL_DIR/protonmail-bridge.rpm"
    if curl -fSL -o "$BRIDGE_PKG" \
        "https://proton.me/download/bridge/protonmail-bridge_linux_x86.rpm" 2>/dev/null; then
      info "Installing Bridge RPM..."
      if is_fedora; then
        sudo dnf install -y "$BRIDGE_PKG" && BRIDGE_OK=1
      else
        sudo zypper --non-interactive install --allow-unsigned-rpm "$BRIDGE_PKG" && BRIDGE_OK=1
      fi
    fi
  elif is_ubuntu; then
    BRIDGE_PKG="$BRIDGE_DL_DIR/protonmail-bridge.deb"
    if curl -fSL -o "$BRIDGE_PKG" \
        "https://proton.me/download/bridge/protonmail-bridge_linux_x86.deb" 2>/dev/null; then
      info "Installing Bridge .deb..."
      sudo apt-get install -y "$BRIDGE_PKG" && BRIDGE_OK=1
    fi
  fi

  rm -rf "$BRIDGE_DL_DIR"

  if [[ $BRIDGE_OK -eq 1 ]]; then
    ok "Proton Mail Bridge installed"
  else
    warn "Automatic download failed — this can happen if Proton changes their download URLs."
    printf "\n"
    warn "Please install Proton Mail Bridge manually:"
    printf "    1. Go to ${BOLD}https://proton.me/mail/bridge${NC}\n"
    if is_fedora || is_opensuse; then
      printf "    2. Download the ${BOLD}.rpm${NC} package\n"
    else
      printf "    2. Download the ${BOLD}.deb${NC} package\n"
    fi
    printf "    3. Double-click the downloaded file to install it\n\n"
  fi
fi

# Prompt user to log in to Proton Mail Bridge
if command -v protonmail-bridge &>/dev/null; then
  printf "\n"
  printf "  ${BOLD}══════════════════════════════════════════════════${NC}\n"
  printf "  ${BOLD}  Proton Mail Bridge — First-Time Login Required  ${NC}\n"
  printf "  ${BOLD}══════════════════════════════════════════════════${NC}\n"
  printf "\n"
  printf "  Proton Mail Bridge must be opened and signed in with\n"
  printf "  your Proton account before GNOME can use it.\n"
  printf "\n"
  read -r -p "  Would you like to open Proton Mail Bridge now? [Y/n] " BRIDGE_RESPONSE </dev/tty || BRIDGE_RESPONSE="n"
  if [[ "$BRIDGE_RESPONSE" =~ ^[Yy]?$ ]] && [[ -n "$BRIDGE_RESPONSE" || -t 0 ]]; then
    info "Starting Proton Mail Bridge..."
    info "Please log in with your Proton account, then close the window when done."
    protonmail-bridge 2>/dev/null &
    BRIDGE_PID=$!
    printf "\n"
    read -r -p "  Press Enter when you have finished logging in... " </dev/tty || true
    ok "Continuing with installation"
  fi
fi

# ── Step 4: Register systemd user services ───────────────────────────────────
step "Step 4 / $TOTAL_STEPS — Registering background services"
info "Reloading systemd user daemon..."
systemctl --user daemon-reload

for svc in protonmail-bridge.service proton-calendar-bridge.service; do
  if systemctl --user list-unit-files "$svc" &>/dev/null; then
    systemctl --user enable "$svc" 2>/dev/null || true
    ok "Enabled $svc"
  fi
done

# Enable proton-drive-bridge for the current user
DRIVE_SVC="proton-drive-bridge@$(id -un).service"
if systemctl --user list-unit-files 'proton-drive-bridge@.service' &>/dev/null; then
  systemctl --user enable "$DRIVE_SVC" 2>/dev/null && ok "Enabled $DRIVE_SVC" || true
fi

ok "Services registered"

# Try to start services
if command -v protonmail-bridge &>/dev/null; then
  systemctl --user start protonmail-bridge.service 2>/dev/null \
    && ok "protonmail-bridge service started" \
    || warn "Could not start protonmail-bridge — start it later with: systemctl --user start protonmail-bridge"
fi

if command -v proton-calendar-bridge &>/dev/null; then
  systemctl --user start proton-calendar-bridge.service 2>/dev/null \
    && ok "proton-calendar-bridge service started" \
    || true
fi

if command -v rclone &>/dev/null; then
  systemctl --user start "$DRIVE_SVC" 2>/dev/null \
    && ok "proton-drive-bridge service started" \
    || warn "Could not start proton-drive-bridge — start it later with: systemctl --user start $DRIVE_SVC"
fi

# ── Final summary ────────────────────────────────────────────────────────────
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║                      All done!                               ║
╚══════════════════════════════════════════════════════════════╝${NC}

  ${BOLD}Next steps:${NC}

    1.  Open ${BOLD}Proton Mail Bridge${NC} from your applications menu
        and sign in with your Proton account.

    2.  Open ${BOLD}GNOME Settings${NC}  →  ${BOLD}Online Accounts${NC}
        and click the Proton option to add your account.

    3.  Done!  Your Proton Mail appears in Evolution / Geary,
        Proton Drive appears in the Files app sidebar,
        and your calendars appear in GNOME Calendar.

  ${BOLD}Useful commands:${NC}
    Check install status :  bash install.sh --status
    View mail bridge logs:  journalctl --user -u protonmail-bridge -f
    View cal bridge logs :  journalctl --user -u proton-calendar-bridge -f
    Uninstall everything :  bash install.sh --uninstall

"
