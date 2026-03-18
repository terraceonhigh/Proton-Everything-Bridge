#!/usr/bin/env bash
# manage.sh — CLI account management for Proton DAV Server
#
# Usage:
#   ./manage.sh add <name>         Add a Proton account and start bridge login
#   ./manage.sh login <name>       Re-run bridge login for an existing account
#   ./manage.sh endpoints <name>   Show service endpoint URLs
#   ./manage.sh status             Show all accounts and service health
#   ./manage.sh remove <name>      Remove an account and all its data
#   ./manage.sh list               List account names

set -euo pipefail

# ── Colours ──────────────────────────────────────────────────────────────────
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

info() { printf "  ${BLUE}→${NC}  %s\n"      "$*"; }
ok()   { printf "  ${GREEN}✓${NC}  %s\n"      "$*"; }
warn() { printf "  ${YELLOW}!${NC}  %s\n"     "$*"; }
die()  { printf "\n  ${RED}✗  ERROR:${NC} %s\n\n" "$*" >&2; exit 1; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
USER_COMPOSE="$SCRIPT_DIR/docker-compose.user.yml"
CADDY_COMPOSE="$SCRIPT_DIR/docker-compose.caddy.yml"

# Load domain from .env
DOMAIN="localhost"
if [[ -f "$SCRIPT_DIR/.env" ]]; then
  DOMAIN=$(grep -E '^DOMAIN=' "$SCRIPT_DIR/.env" | cut -d= -f2- || echo "localhost")
fi

# ── Helpers ──────────────────────────────────────────────────────────────────

project_name() { echo "user-$1"; }

validate_name() {
  local name="$1"
  if [[ ! "$name" =~ ^[a-z][a-z0-9_-]{0,31}$ ]]; then
    die "Invalid account name '$name'. Must be lowercase, start with a letter, max 32 chars (a-z, 0-9, -, _)."
  fi
}

# Find the Caddy container name dynamically
caddy_container() {
  docker compose -f "$CADDY_COMPOSE" ps --format '{{.Names}}' 2>/dev/null | grep caddy | head -1
}

# Add Caddy routes for a user via the admin API (called from inside the Caddy container)
add_caddy_routes() {
  local name="$1"
  local project
  project=$(project_name "$name")
  local prefix="/users/$name"
  local container
  container=$(caddy_container)

  if [[ -z "$container" ]]; then
    warn "Caddy container not found — skipping route setup."
    warn "Routes will be added on next restart (reconciliation)."
    return 1
  fi

  local container="${project}-proton-bridge-1"
  local -a services=(
    "caldav:${container}:9842"
    "webdav:${container}:9844"
    "carddav:${container}:8080"
  )

  for entry in "${services[@]}"; do
    local svc="${entry%%:*}"
    local upstream="${entry#*:}"
    local route_id="user-${name}-${svc}"

    local route_json
    route_json=$(cat <<ROUTEEOF
{
  "@id": "${route_id}",
  "match": [{"path": ["${prefix}/${svc}/*"]}],
  "handle": [{
    "handler": "subroute",
    "routes": [{
      "handle": [
        {"handler": "rewrite", "strip_path_prefix": "${prefix}/${svc}"},
        {"handler": "reverse_proxy", "upstreams": [{"dial": "${upstream}"}]}
      ]
    }]
  }]
}
ROUTEEOF
)

    # Use wget inside the Caddy Alpine container (no curl available)
    docker exec "$container" wget -q -O /dev/null \
      --header="Content-Type: application/json" \
      --post-data="$route_json" \
      "http://localhost:2019/config/apps/http/servers/srv0/routes" 2>/dev/null && \
      ok "Route: $svc → $upstream" || \
      warn "Route $svc failed (service may not be running yet)"
  done
}

# Remove Caddy routes for a user
remove_caddy_routes() {
  local name="$1"
  local container
  container=$(caddy_container)

  if [[ -z "$container" ]]; then
    return 0
  fi

  for svc in caldav webdav carddav; do
    local route_id="user-${name}-${svc}"
    docker exec "$container" wget -q -O /dev/null \
      --method=DELETE \
      "http://localhost:2019/id/${route_id}" 2>/dev/null || true
  done
}

# ── Commands ─────────────────────────────────────────────────────────────────

cmd_add() {
  local name="${1:-}"
  [[ -z "$name" ]] && die "Usage: $0 add <name>"
  validate_name "$name"

  # Check if already exists
  if docker compose -p "$(project_name "$name")" -f "$USER_COMPOSE" ps --quiet 2>/dev/null | grep -q .; then
    die "Account '$name' already exists. Use '$0 login $name' to re-authenticate."
  fi

  printf "\n${BOLD}Adding account: ${name}${NC}\n\n"

  # Build image only — don't start yet (no credentials = crash loop)
  info "Building bridge container..."
  (cd "$SCRIPT_DIR" && docker compose -p "$(project_name "$name")" -f "$USER_COMPOSE" build 2>&1 | sed 's/^/    /')
  ok "Image built"

  # Interactive login populates the shared volume with credentials
  cmd_login "$name"

  # Add Caddy routes
  info "Configuring reverse proxy routes..."
  add_caddy_routes "$name"

  printf "\n${BOLD}Account '$name' ready.${NC}\n"
}

cmd_login() {
  local name="${1:-}"
  [[ -z "$name" ]] && die "Usage: $0 login <name>"
  validate_name "$name"

  local project
  project=$(project_name "$name")

  printf "
${BOLD}━━  Bridge Login for '$name'  ━━${NC}

  You need to authenticate with Proton in each bridge.
  This is a one-time setup — credentials are stored in Docker volumes.

"

  # Stop any running containers first (avoids lock file conflicts)
  (cd "$SCRIPT_DIR" && docker compose -p "$project" -f "$USER_COMPOSE" stop 2>/dev/null) || true

  # ── Step 1: Mail Bridge ──────────────────────────────────────────────────
  printf "${BOLD}Step 1 / 3 — Mail Bridge${NC}\n\n"
  printf "  Inside the bridge CLI:\n"
  printf "    ${DIM}> login${NC}                    (enter your Proton email + password)\n"
  printf "    ${DIM}> info${NC}                     (note the ${BOLD}bridge password${NC} — you'll need it)\n"
  printf "    ${DIM}> exit${NC}\n\n"

  read -r -p "  Press Enter to open Mail Bridge CLI... " </dev/tty || true
  (cd "$SCRIPT_DIR" && docker compose -p "$project" -f "$USER_COMPOSE" \
    run --rm proton-bridge protonmail-bridge --cli) </dev/tty || \
    warn "Mail Bridge login failed or was skipped"

  printf "\n"

  # ── Step 2: Calendar Bridge ─────────────────────────────────────────────
  printf "${BOLD}Step 2 / 3 — Calendar Bridge${NC}\n\n"
  printf "  Follow the prompts to log in with your Proton credentials.\n\n"

  read -r -p "  Press Enter to open Calendar Bridge login... " </dev/tty || true
  (cd "$SCRIPT_DIR" && docker compose -p "$project" -f "$USER_COMPOSE" \
    run --rm proton-bridge proton-calendar-bridge --login) </dev/tty || \
    warn "Calendar Bridge login failed or was skipped"

  printf "\n"

  # ── Step 3: Drive (rclone) ──────────────────────────────────────────────
  printf "${BOLD}Step 3 / 3 — Drive (rclone)${NC}\n\n"
  printf "  Inside rclone config:\n"
  printf "    ${DIM}n${NC}              (new remote)\n"
  printf "    ${DIM}proton${NC}         (name it 'proton')\n"
  printf "    ${DIM}protondrive${NC}    (storage type)\n"
  printf "    ${DIM}(follow prompts for Proton credentials)${NC}\n\n"

  read -r -p "  Press Enter to open rclone config... " </dev/tty || true
  (cd "$SCRIPT_DIR" && docker compose -p "$project" -f "$USER_COMPOSE" \
    run --rm proton-bridge rclone config) </dev/tty || \
    warn "rclone config failed or was skipped"

  # Start the container with credentials now in place
  printf "\n"
  info "Starting bridge services..."
  (cd "$SCRIPT_DIR" && docker compose -p "$project" -f "$USER_COMPOSE" up -d 2>&1 | sed 's/^/    /')

  printf "
${BOLD}━━  Login complete!  ━━${NC}

"
  ok "Bridges are authenticating with Proton."
  info "It may take a minute for services to become healthy."
  printf "\n"
  info "View endpoints:  ./manage.sh endpoints $name"
  info "Check health:    ./manage.sh status"
  printf "\n"
}

cmd_endpoints() {
  local name="${1:-}"
  [[ -z "$name" ]] && die "Usage: $0 endpoints <name>"
  validate_name "$name"

  local scheme="https"
  [[ "$DOMAIN" == "localhost" ]] && scheme="https"

  printf "
${BOLD}━━  Endpoint URLs for '$name'  ━━${NC}

  ${BOLD}IMAP (Mail — incoming):${NC}
    Server:   $DOMAIN
    Port:     1143  ${DIM}(via container: $(project_name "$name")-proton-bridge-1)${NC}
    Security: STARTTLS
    ${DIM}Note: Use the bridge password from 'protonmail-bridge --cli > info'${NC}

  ${BOLD}SMTP (Mail — outgoing):${NC}
    Server:   $DOMAIN
    Port:     1025
    Security: STARTTLS

  ${BOLD}CalDAV (Calendar):${NC}
    URL:      ${scheme}://${DOMAIN}/users/${name}/caldav/
    ${DIM}Uses your Proton credentials${NC}

  ${BOLD}WebDAV (Drive):${NC}
    URL:      ${scheme}://${DOMAIN}/users/${name}/webdav/
    ${DIM}Uses your Proton credentials${NC}

  ${BOLD}CardDAV (Contacts — experimental):${NC}
    URL:      ${scheme}://${DOMAIN}/users/${name}/carddav/
    ${DIM}Requires hydroxide profile enabled${NC}

"
}

cmd_status() {
  printf "\n${BOLD}Proton DAV Server — Status${NC}\n\n"

  # Shared infra
  printf "  ${BOLD}Infrastructure:${NC}\n"
  (cd "$SCRIPT_DIR" && docker compose -f "$CADDY_COMPOSE" ps --format "table {{.Name}}\t{{.Status}}" 2>/dev/null) | sed 's/^/    /' || warn "Not running"
  printf "\n"

  # User stacks
  local users
  users=$(docker compose ls --format json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in data:
    if p['Name'].startswith('user-'):
        print(p['Name'][5:])
" 2>/dev/null || true)

  if [[ -z "$users" ]]; then
    info "No accounts found. Use './manage.sh add <name>' to add one."
    printf "\n"
    return
  fi

  printf "  ${BOLD}Accounts:${NC}\n\n"
  while IFS= read -r name; do
    local project
    project=$(project_name "$name")
    printf "  ${BOLD}$name${NC}\n"

    (cd "$SCRIPT_DIR" && docker compose -p "$project" -f "$USER_COMPOSE" \
      ps --format "table {{.Service}}\t{{.State}}\t{{.Health}}" 2>/dev/null) | sed 's/^/    /' || true
    printf "\n"
  done <<< "$users"
}

cmd_list() {
  docker compose ls --format json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
for p in data:
    if p['Name'].startswith('user-'):
        print(p['Name'][5:])
" 2>/dev/null || true
}

cmd_remove() {
  local name="${1:-}"
  [[ -z "$name" ]] && die "Usage: $0 remove <name>"
  validate_name "$name"

  local project
  project=$(project_name "$name")

  printf "\n"
  read -r -p "  Remove account '$name' and ALL its data? [y/N] " RESPONSE </dev/tty || RESPONSE="n"
  if [[ ! "$RESPONSE" =~ ^[Yy]$ ]]; then
    info "Cancelled."
    return
  fi

  info "Removing Caddy routes..."
  remove_caddy_routes "$name"

  info "Stopping and removing containers..."
  (cd "$SCRIPT_DIR" && docker compose -p "$project" -f "$USER_COMPOSE" down -v 2>&1 | sed 's/^/    /')

  ok "Account '$name' removed."
  printf "\n"
}

# ── Main ─────────────────────────────────────────────────────────────────────
cmd="${1:-}"
shift || true

case "$cmd" in
  add)       cmd_add "$@" ;;
  login)     cmd_login "$@" ;;
  endpoints) cmd_endpoints "$@" ;;
  status)    cmd_status ;;
  list)      cmd_list ;;
  remove)    cmd_remove "$@" ;;
  *)
    printf "
${BOLD}Proton DAV Server — Account Manager${NC}

  Usage: ./manage.sh <command> [name]

  ${BOLD}Commands:${NC}
    add <name>         Add a new Proton account (creates containers + login)
    login <name>       Re-run bridge login for an existing account
    endpoints <name>   Show service endpoint URLs for clients
    status             Show all accounts and service health
    list               List account names
    remove <name>      Remove an account and all its data

  ${BOLD}Examples:${NC}
    ./manage.sh add alice
    ./manage.sh endpoints alice
    ./manage.sh status

"
    ;;
esac
