#!/usr/bin/env bash
# install-server.sh — Proton DAV Server — guided installer
#
# Sets up the shared infrastructure (Caddy + dashboard).
# Account management is done via the web dashboard after install.
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
COMPOSE_FILE="docker-compose.caddy.yml"

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
    printf "  ${BOLD}Shared infrastructure:${NC}\n"
    ( cd "$SCRIPT_DIR" && docker compose -f "$COMPOSE_FILE" ps 2>/dev/null ) || warn "Not running"

    printf "\n  ${BOLD}User stacks:${NC}\n"
    docker compose ls --format "table" 2>/dev/null | grep "^user-" || info "No user stacks found"
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

  # Stop user stacks first
  for project in $(docker compose ls --format json 2>/dev/null | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    if p['Name'].startswith('user-'):
        print(p['Name'])
" 2>/dev/null); do
    info "Stopping user stack: $project"
    docker compose -p "$project" -f docker-compose.user.yml down 2>/dev/null || true
  done

  info "Stopping shared infrastructure..."
  docker compose -f "$COMPOSE_FILE" down 2>/dev/null && ok "Infrastructure stopped" || warn "Not running"

  # Remove shared network
  docker network rm proton-shared 2>/dev/null || true

  printf "\n"
  read -r -p "  Remove all data volumes (credentials, caches)? [y/N] " RESPONSE </dev/tty || RESPONSE="n"
  if [[ "$RESPONSE" =~ ^[Yy]$ ]]; then
    # Remove user stack volumes
    for project in $(docker compose ls --format json 2>/dev/null | python3 -c "
import sys, json
for p in json.load(sys.stdin):
    if p['Name'].startswith('user-'):
        print(p['Name'])
" 2>/dev/null); do
      docker compose -p "$project" -f docker-compose.user.yml down -v 2>/dev/null || true
    done
    docker compose -f "$COMPOSE_FILE" down -v 2>/dev/null || true
    ok "Volumes removed"
  else
    info "Volumes preserved."
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
    4.  Build and start the server

  After setup, open the dashboard to add your Proton accounts.

  Distribution detected: ${BOLD}${DISTRO_LABEL}${NC}

"

# ── Step 1: Install Docker ─────────────────────────────────────────────────
step "Step 1 / 4 — Installing Docker"

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
step "Step 2 / 4 — Configuring access control"

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
step "Step 3 / 4 — Setting up authentication"

printf "\n  These credentials protect the dashboard and all service endpoints.\n\n"

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

# ── Write .env file ───────────────────────────────────────────────────────
step "Step 4 / 4 — Building and starting server"

cd "$SCRIPT_DIR"
cat > .env << ENVEOF
# Generated by install-server.sh on $(date -Iseconds)
DOMAIN=$DOMAIN
ACCESS_MODE=$ACCESS_MODE
ALLOWED_RANGES=$ALLOWED_RANGES
BIND_ADDRESS=$BIND_ADDRESS
AUTH_USER=$AUTH_USER
AUTH_HASH=$AUTH_HASH
ENVEOF
ok ".env file written"

# ── Create shared network ────────────────────────────────────────────────
docker network create proton-shared 2>/dev/null || true
ok "Shared network ready"

# ── Build and start ───────────────────────────────────────────────────────
info "Building containers (this may take a few minutes on first run)..."
docker compose -f "$COMPOSE_FILE" build 2>&1 | sed 's/^/    /'
ok "Containers built"

info "Starting Caddy + dashboard..."
docker compose -f "$COMPOSE_FILE" up -d 2>&1 | sed 's/^/    /'
ok "Server started"

# ── Final summary ────────────────────────────────────────────────────────
printf "
${BOLD}╔══════════════════════════════════════════════════════════════╗
║                      All done!                               ║
╚══════════════════════════════════════════════════════════════╝${NC}

  ${BOLD}Your Proton DAV Server is running.${NC}

  ${BOLD}Dashboard:${NC}   https://$DOMAIN/
  ${BOLD}Access:${NC}      $ACCESS_MODE
  ${BOLD}Username:${NC}    $AUTH_USER

  ${BOLD}Next step:${NC}
    Open ${BOLD}https://$DOMAIN/${NC} in your browser.
    Click ${BOLD}[+ Add Account]${NC} to add your first Proton account.

    The dashboard will guide you through bridge login and
    show you the endpoint URLs for your apps.

  ${BOLD}Useful commands:${NC}
    Check status :  bash install-server.sh --status
    View logs    :  docker compose -f $COMPOSE_FILE logs -f
    Restart      :  docker compose -f $COMPOSE_FILE restart
    Stop         :  docker compose -f $COMPOSE_FILE down
    Uninstall    :  bash install-server.sh --uninstall

"
