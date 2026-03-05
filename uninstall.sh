#!/usr/bin/env bash
# uninstall.sh — Proton on GNOME Online Accounts — one-command uninstaller
#
# Removes everything that install.sh put on the system:
#   • Proton GOA plugin (.so)
#   • proton-calendar-bridge binary
#   • systemd user unit files (protonmail-bridge, proton-calendar-bridge,
#     proton-drive-bridge@)
#
# Proton Mail Bridge (installed via your package manager) is not removed
# automatically; the script will print the command to do so.
#
# Usage:
#   bash uninstall.sh
#   bash uninstall.sh --help

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
for arg in "$@"; do
  case "$arg" in
    --help|-h)
      printf "Usage: bash uninstall.sh\n\n"
      printf "Removes everything installed by install.sh:\n"
      printf "  • Proton GOA plugin (.so)\n"
      printf "  • proton-calendar-bridge binary (/usr/local/bin/)\n"
      printf "  • systemd user unit files\n\n"
      printf "Proton Mail Bridge (package-manager-installed) is not removed\n"
      printf "automatically — the command to do so will be printed.\n"
      exit 0
      ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

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
else die "Your distribution ($DISTRO_ID) is not supported.
         Supported: Fedora, Ubuntu/Debian, openSUSE."
fi

# ── Banner ────────────────────────────────────────────────────────────────────
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║     Proton  ▶  GNOME Online Accounts  —  Uninstaller         ║
╚══════════════════════════════════════════════════════════════╝${NC}

  Distribution detected: ${BOLD}${DISTRO_LABEL}${NC}

"

# ── Step 1: Stop and disable proton-drive-bridge instances ───────────────────
step "Step 1 / 4 — Stopping Proton Drive mount(s)"

# Find all running proton-drive-bridge@ instances
DRIVE_INSTANCES=$(systemctl --user list-units --no-legend --plain \
  'proton-drive-bridge@*' 2>/dev/null \
  | awk '{print $1}' || true)

if [ -n "$DRIVE_INSTANCES" ]; then
  while IFS= read -r instance; do
    info "Stopping $instance..."
    systemctl --user stop "$instance" 2>/dev/null && ok "Stopped $instance" || warn "Could not stop $instance — it may already be stopped"
  done <<< "$DRIVE_INSTANCES"
else
  info "No running proton-drive-bridge instances found"
fi

# Unmount ~/ProtonDrive if still mounted
MOUNT_POINT="$HOME/ProtonDrive"
if mountpoint -q "$MOUNT_POINT" 2>/dev/null; then
  info "Unmounting $MOUNT_POINT..."
  fusermount -u "$MOUNT_POINT" 2>/dev/null \
    && ok "Unmounted $MOUNT_POINT" \
    || warn "Could not unmount $MOUNT_POINT — you may need to run: fusermount -u $MOUNT_POINT"
else
  info "$MOUNT_POINT is not mounted"
fi

# Disable the template unit if it is enabled
if systemctl --user list-unit-files 'proton-drive-bridge@.service' &>/dev/null 2>&1; then
  systemctl --user disable 'proton-drive-bridge@.service' 2>/dev/null && ok "Disabled proton-drive-bridge@.service" || true
fi

# ── Step 2: Stop and disable remaining services ──────────────────────────────
step "Step 2 / 4 — Stopping and disabling services"

for svc in protonmail-bridge.service proton-calendar-bridge.service; do
  if systemctl --user is-active "$svc" &>/dev/null; then
    systemctl --user stop "$svc" 2>/dev/null \
      && ok "Stopped $svc" \
      || warn "Could not stop $svc"
  else
    info "$svc is not running"
  fi

  if systemctl --user is-enabled "$svc" &>/dev/null 2>&1; then
    systemctl --user disable "$svc" 2>/dev/null \
      && ok "Disabled $svc" \
      || warn "Could not disable $svc"
  else
    info "$svc is not enabled"
  fi
done

# ── Step 3: Remove installed files ───────────────────────────────────────────
step "Step 3 / 4 — Removing installed files"

# Remove systemd user unit files
UNIT_DIR="/usr/lib/systemd/user"
for unit in protonmail-bridge.service proton-calendar-bridge.service "proton-drive-bridge@.service"; do
  UNIT_PATH="$UNIT_DIR/$unit"
  if [ -e "$UNIT_PATH" ]; then
    sudo rm -f "$UNIT_PATH" && ok "Removed $UNIT_PATH"
  else
    info "$UNIT_PATH not found — already removed or never installed"
  fi
done

# Reload the systemd user daemon now that unit files are gone
info "Reloading systemd user daemon..."
systemctl --user daemon-reload 2>/dev/null || true
ok "systemd user daemon reloaded"

# Remove GOA plugin
for p in /usr/lib64/gnome-online-accounts/goa-proton.so \
         /usr/lib/gnome-online-accounts/goa-proton.so; do
  if [ -e "$p" ]; then
    sudo rm -f "$p" && ok "Removed $p"
  fi
done

# Remove proton-calendar-bridge binary
if [ -e /usr/local/bin/proton-calendar-bridge ]; then
  sudo rm -f /usr/local/bin/proton-calendar-bridge \
    && ok "Removed /usr/local/bin/proton-calendar-bridge"
else
  info "/usr/local/bin/proton-calendar-bridge not found — already removed or never installed"
fi

# ── Step 4: Proton Mail Bridge ───────────────────────────────────────────────
step "Step 4 / 4 — Proton Mail Bridge"

if command -v protonmail-bridge &>/dev/null; then
  warn "Proton Mail Bridge is still installed (it was installed via your package manager)."
  printf "\n"

  if   is_fedora;   then PM_CMD="sudo dnf remove protonmail-bridge"
  elif is_ubuntu;   then PM_CMD="sudo apt-get remove protonmail-bridge"
  elif is_opensuse; then PM_CMD="sudo zypper remove protonmail-bridge"
  fi

  printf "  To remove it, run:\n\n"
  printf "    ${BOLD}%s${NC}\n\n" "$PM_CMD"
else
  ok "Proton Mail Bridge is not installed (or was already removed)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║                   Uninstall complete!                        ║
╚══════════════════════════════════════════════════════════════╝${NC}

  The Proton GOA plugin, calendar bridge, and systemd unit files
  have been removed.

  ${BOLD}Optional manual steps:${NC}

    • Remove ~/ProtonDrive if you no longer need it:
        ${BOLD}rm -rf ~/ProtonDrive${NC}

    • Remove rclone Proton Drive configuration (if set up):
        ${BOLD}rclone config delete proton${NC}

    • Remove Proton Mail Bridge (see Step 4 above if still installed).

"
