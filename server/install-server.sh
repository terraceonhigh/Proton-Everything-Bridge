#!/usr/bin/env bash
# install-server.sh — Proton DAV Server — guided installer
#
# Recycled from: install.sh (desktop GNOME installer)
# Key differences:
#   - Installs Docker + Docker Compose instead of meson/gcc/GOA libs
#   - Configures access tiers instead of GNOME provider registration
#   - Sets up .env instead of systemd user services
#   - Bridge login via docker compose exec instead of direct binary
#
# Usage:
#   bash install-server.sh              — full guided install
#   bash install-server.sh --status     — check what is running
#   bash install-server.sh --uninstall  — stop and remove containers

set -euo pipefail

# ── Colours (recycled from install.sh lines 20-26) ─────────────────────────
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

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# ── Parse arguments (recycled from install.sh lines 35-55) ─────────────────
STATUS_ONLY=0
UNINSTALL=0

for arg in "$@"; do
  case "$arg" in
    --status)    STATUS_ONLY=1 ;;
    --uninstall) UNINSTALL=1 ;;
    --help|-h)
      printf "Usage: bash install-server.sh [OPTIONS]\n\n"
      printf "Options:\n"
      printf "  --status      Check server and container status\n"
      printf "  --uninstall   Stop and remove all containers and volumes\n"
      printf "  --help        Show this help\n"
      exit 0
      ;;
    *) die "Unknown option: $arg (try --help)" ;;
  esac
done

# ── Detect distro (recycled from install.sh lines 57-75) ──────────────────
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
is_arch()     { [[ "$DISTRO_ID" == arch || "$DISTRO_LIKE" == *arch* ]]; }

if   is_fedora;   then DISTRO_LABEL="Fedora"
elif is_ubuntu;   then DISTRO_LABEL="Ubuntu / Debian"
elif is_opensuse; then DISTRO_LABEL="openSUSE"
elif is_arch;     then DISTRO_LABEL="Arch Linux"
else DISTRO_LABEL="$DISTRO_ID (best-effort)"
fi

# ─────────────────────────────────────────────────────────────────────────────
# STATUS MODE
# ─────────────────────────────────────────────────────────────────────────────
if [[ $STATUS_ONLY -eq 1 ]]; then
  printf "\n${BOLD}Proton DAV Server — status check${NC}\n\n"
  printf "  Distribution : %s\n\n" "$DISTRO_LABEL"

  _check_cmd() {
    local label="$1"; shift
    if command -v "$1" &>/dev/null; then
      printf "  ${GREEN}✓${NC}  %-25s %s\n" "$label" "$(command -v "$1")"
    else
      printf "  ${RED}✗${NC}  %-25s not found\n" "$label"
    fi
  }
  _check_cmd "docker"          docker
  _check_cmd "docker compose"  docker

  printf "\n"
  if command -v docker &>/dev/null; then
    printf "  ${BOLD}Container status:${NC}\n"
    ( cd "$SCRIPT_DIR" && docker compose ps 2>/dev/null ) || warn "Containers not running"
  fi
  printf "\n"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# UNINSTALL MODE
# ─────────────────────────────────────────────────────────────────────────────
if [[ $UNINSTALL -eq 1 ]]; then
  printf "\n${BOLD}Proton DAV Server — uninstall${NC}\n\n"
  cd "$SCRIPT_DIR"

  info "Stopping containers..."
  docker compose down 2>/dev/null && ok "Containers stopped" || warn "No containers running"

  printf "\n"
  read -r -p "  Remove all data volumes (credentials, caches)? [y/N] " RESPONSE </dev/tty || RESPONSE="n"
  if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    docker compose down -v 2>/dev/null && ok "Volumes removed"
  else
    info "Volumes preserved. Remove manually with: docker compose down -v"
  fi

  printf "\n  ${GREEN}Done.${NC}\n\n"
  exit 0
fi

# ─────────────────────────────────────────────────────────────────────────────
# FULL INSTALL
# ─────────────────────────────────────────────────────────────────────────────

clear
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║       Proton DAV Server  —  Guided Setup                   ║
╚══════════════════════════════════════════════════════════════╝${NC}

  This script will:
    1.  Install Docker (if needed)
    2.  Configure access control (localhost/LAN/whitelist/internet)
    3.  Set up authentication credentials
    4.  Build and start all Proton bridge containers
    5.  Guide you through bridge login

  Distribution detected: ${BOLD}${DISTRO_LABEL}${NC}

"

# ── Step 1: Install Docker ─────────────────────────────────────────────────
step "Step 1 / 5 — Installing Docker"

if command -v docker &>/dev/null && docker compose version &>/dev/null; then
  ok "Docker and Docker Compose already installed"
else
  info "Installing Docker..."

  if is_fedora; then
    sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin 2>/dev/null || \
    sudo dnf install -y moby-engine docker-compose 2>/dev/null || \
    { info "Using official Docker install script..."; curl -fsSL https://get.docker.com | sudo sh; }

  elif is_ubuntu; then
    sudo apt-get update -qq
    sudo apt-get install -y docker.io docker-compose-plugin 2>/dev/null || \
    { info "Using official Docker install script..."; curl -fsSL https://get.docker.com | sudo sh; }

  elif is_opensuse; then
    sudo zypper --non-interactive install docker docker-compose 2>/dev/null || \
    { info "Using official Docker install script..."; curl -fsSL https://get.docker.com | sudo sh; }

  elif is_arch; then
    sudo pacman -S --noconfirm docker docker-compose 2>/dev/null || \
    { info "Using official Docker install script..."; curl -fsSL https://get.docker.com | sudo sh; }

  else
    info "Using official Docker install script..."
    curl -fsSL https://get.docker.com | sudo sh
  fi

  sudo systemctl enable --now docker
  sudo usermod -aG docker "$USER" 2>/dev/null || true
  ok "Docker installed"
fi

# ── Step 2: Configure Access Control ───────────────────────────────────────
step "Step 2 / 5 — Configuring access control"

printf "
  Who should be able to connect to this server?

    1) ${BOLD}localhost${NC}  — Only this machine (safest)
    2) ${BOLD}lan${NC}       — Devices on your local network
    3) ${BOLD}whitelist${NC} — Specific IP addresses you choose
    4) ${BOLD}internet${NC}  — Anyone on the internet (requires a domain)

"
read -r -p "  Choose [1-4, default 1]: " ACCESS_CHOICE </dev/tty || ACCESS_CHOICE="1"

case "$ACCESS_CHOICE" in
  2)
    ACCESS_MODE="lan"
    ALLOWED_RANGES="192.168.0.0/16 10.0.0.0/8 172.16.0.0/12 fd00::/8"
    BIND_ADDRESS="0.0.0.0"
    ok "Access mode: LAN (private networks only)"
    ;;
  3)
    ACCESS_MODE="whitelist"
    printf "\n"
    read -r -p "  Enter allowed IPs/CIDRs (space-separated): " ALLOWED_IPS </dev/tty || ALLOWED_IPS=""
    [ -z "$ALLOWED_IPS" ] && die "No IPs provided."
    ALLOWED_RANGES="$ALLOWED_IPS"
    BIND_ADDRESS="0.0.0.0"
    ok "Access mode: whitelist ($ALLOWED_IPS)"
    ;;
  4)
    ACCESS_MODE="internet"
    ALLOWED_RANGES="0.0.0.0/0 ::/0"
    BIND_ADDRESS="0.0.0.0"
    warn "Internet mode selected — anyone can reach your server."
    warn "Make sure you use a strong password and a real domain for TLS."
    printf "\n"
    read -r -p "  Enter your domain name (e.g., proton.example.com): " DOMAIN </dev/tty || DOMAIN=""
    [ -z "$DOMAIN" ] && die "A domain is required for internet mode (for TLS certificates)."
    ok "Access mode: internet (domain: $DOMAIN)"
    ;;
  *)
    ACCESS_MODE="localhost"
    ALLOWED_RANGES="127.0.0.1/32 ::1/128"
    BIND_ADDRESS="127.0.0.1"
    ok "Access mode: localhost (this machine only)"
    ;;
esac

DOMAIN="${DOMAIN:-localhost}"

# ── Step 3: Set up authentication ─────────────────────────────────────────
step "Step 3 / 5 — Setting up authentication"

read -r -p "  Choose a username [default: proton]: " AUTH_USER </dev/tty || AUTH_USER=""
AUTH_USER="${AUTH_USER:-proton}"

while true; do
  printf "\n"
  read -r -s -p "  Choose a password: " AUTH_PASS </dev/tty || AUTH_PASS=""
  printf "\n"
  [ -n "$AUTH_PASS" ] && break
  warn "Password cannot be empty."
done

info "Generating password hash..."
AUTH_HASH=$(docker run --rm caddy:2-alpine caddy hash-password --plaintext "$AUTH_PASS" 2>/dev/null) || \
  die "Failed to generate password hash. Is Docker running?"
ok "Credentials configured (user: $AUTH_USER)"

# ── Step 4: CardDAV (experimental) ─────────────────────────────────────────
printf "\n"
read -r -p "  Enable CardDAV contacts sync? (experimental, uses hydroxide) [y/N]: " CARDDAV_CHOICE </dev/tty || CARDDAV_CHOICE="n"
if [[ "$CARDDAV_CHOICE" =~ ^[Yy]$ ]]; then
  ENABLE_CARDDAV=true
  COMPOSE_PROFILES="carddav"
  ok "CardDAV enabled (experimental)"
else
  ENABLE_CARDDAV=false
  COMPOSE_PROFILES=""
  info "CardDAV disabled"
fi

# ── Write .env file ───────────────────────────────────────────────────────
step "Step 4 / 5 — Building and starting containers"

cd "$SCRIPT_DIR"
cat > .env << ENVEOF
# Generated by install-server.sh on $(date -Iseconds)
DOMAIN=$DOMAIN
ACCESS_MODE=$ACCESS_MODE
ALLOWED_RANGES=$ALLOWED_RANGES
BIND_ADDRESS=$BIND_ADDRESS
AUTH_USER=$AUTH_USER
AUTH_HASH=$AUTH_HASH
ENABLE_CARDDAV=$ENABLE_CARDDAV
COMPOSE_PROFILES=$COMPOSE_PROFILES
ENVEOF
ok ".env file written"

# ── Build and start ───────────────────────────────────────────────────────
info "Building containers (this may take a few minutes on first run)..."
docker compose build 2>&1 | sed 's/^/    /'
ok "Containers built"

info "Starting services..."
docker compose up -d 2>&1 | sed 's/^/    /'
ok "Services started"

# ── Step 5: Bridge login guidance ─────────────────────────────────────────
step "Step 5 / 5 — Bridge setup"

# Recycled from install.sh lines 400-420: interactive bridge login guidance
printf "
  ${BOLD}══════════════════════════════════════════════════════════════${NC}
  ${BOLD}  Bridge Login Required                                      ${NC}
  ${BOLD}══════════════════════════════════════════════════════════════${NC}

  Each bridge needs to be authenticated with your Proton account.
  Run these commands to log in:

  ${BOLD}Mail Bridge:${NC}
    docker compose exec proton-mail-bridge protonmail-bridge --cli
    > login
    > (enter Proton credentials)
    > info   (note the bridge password for your email client)
    > exit

  ${BOLD}rclone (Drive):${NC}
    docker compose exec rclone-webdav rclone config
    > n      (new remote)
    > proton (name it 'proton')
    > protondrive (type)
    > (follow prompts for Proton login)

"

if [[ "$ENABLE_CARDDAV" == "true" ]]; then
  printf "  ${BOLD}hydroxide (Contacts, experimental):${NC}
    docker compose exec hydroxide hydroxide auth YOUR_PROTON_USERNAME
    > (enter Proton password)

"
fi

# ── Final summary ────────────────────────────────────────────────────────
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║                      All done!                               ║
╚══════════════════════════════════════════════════════════════╝${NC}

  ${BOLD}Your Proton DAV Server is running.${NC}

  ${BOLD}Access mode:${NC} $ACCESS_MODE
  ${BOLD}Domain:${NC}      $DOMAIN
  ${BOLD}Username:${NC}    $AUTH_USER

  ${BOLD}Endpoints:${NC}
    CalDAV  (calendar)  https://$DOMAIN/caldav/
    WebDAV  (files)     https://$DOMAIN/webdav/
    IMAP    (mail)      $DOMAIN:993
    SMTP    (mail)      $DOMAIN:465
"
if [[ "$ENABLE_CARDDAV" == "true" ]]; then
  printf "    CardDAV (contacts)  https://$DOMAIN/carddav/  (experimental)
"
fi
printf "
  ${BOLD}Client setup:${NC}
    iOS/macOS:    Settings → Calendar → Add Account → Other →
                  CalDAV → Server: $DOMAIN
    Thunderbird:  New Calendar → Network → CalDAV →
                  https://$DOMAIN/.well-known/caldav
    DAVx5:       Base URL: https://$DOMAIN
    Windows:     Map Network Drive → https://$DOMAIN/webdav/

  ${BOLD}Useful commands:${NC}
    Check status :  bash install-server.sh --status
    View logs    :  docker compose logs -f
    Restart      :  docker compose restart
    Stop         :  docker compose down
    Uninstall    :  bash install-server.sh --uninstall

"
