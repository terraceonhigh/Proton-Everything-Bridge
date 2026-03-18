#!/usr/bin/env bash
set -euo pipefail

# Proton Everything Bridge — Mode 1 (Bash launcher)
# Starts each service independently. Each handles its own auth.
# Kill all with: Ctrl+C (or kill the process group)
#
# Prerequisites:
#   - hydroxide: go install github.com/emersion/hydroxide/cmd/hydroxide@latest
#     then: hydroxide auth <username>
#   - proton-calendar-bridge: build from submodule or install
#     then: proton-calendar-bridge --login
#   - rclone: brew install rclone (or package manager)
#     then: rclone config (add a "proton" remote of type protondrive)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# --- Configuration (override via environment) ---
HYDROXIDE_BIN="${HYDROXIDE_BIN:-hydroxide}"
CALENDAR_BRIDGE_BIN="${CALENDAR_BRIDGE_BIN:-proton-calendar-bridge}"
RCLONE_BIN="${RCLONE_BIN:-rclone}"

IMAP_PORT="${IMAP_PORT:-1143}"
SMTP_PORT="${SMTP_PORT:-1025}"
CARDDAV_PORT="${CARDDAV_PORT:-8080}"
CALDAV_PORT="${CALDAV_PORT:-9842}"
WEBDAV_PORT="${WEBDAV_PORT:-9844}"

RCLONE_REMOTE="${RCLONE_REMOTE:-proton}"

LOG_DIR="${LOG_DIR:-$ROOT_DIR/logs}"

# --- Colors ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# --- Cleanup ---
PIDS=()

cleanup() {
    echo ""
    echo -e "${YELLOW}Shutting down all services...${NC}"
    for pid in "${PIDS[@]}"; do
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null || true
        fi
    done
    wait 2>/dev/null
    echo -e "${GREEN}All services stopped.${NC}"
    exit 0
}
trap cleanup SIGINT SIGTERM EXIT

mkdir -p "$LOG_DIR"

# --- Helper ---
start_service() {
    local name="$1"
    shift
    local logfile="$LOG_DIR/${name}.log"

    if ! command -v "$1" &>/dev/null && [ ! -x "$1" ]; then
        echo -e "${RED}[SKIP]${NC} $name — binary not found: $1"
        return 1
    fi

    echo -e "${BLUE}[START]${NC} $name → $logfile"
    "$@" >> "$logfile" 2>&1 &
    local pid=$!
    PIDS+=("$pid")
    echo -e "${GREEN}[OK]${NC}   $name (PID $pid)"
    return 0
}

echo -e "${PURPLE}============================================${NC}"
echo -e "${PURPLE} Proton Everything Bridge — Mode 1 (Bash)${NC}"
echo -e "${PURPLE}============================================${NC}"
echo ""

# --- Start hydroxide (IMAP + SMTP + CardDAV) ---
start_service "hydroxide" "$HYDROXIDE_BIN" serve \
    -smtp-host 127.0.0.1 -smtp-port "$SMTP_PORT" \
    -imap-host 127.0.0.1 -imap-port "$IMAP_PORT" \
    -carddav-host 127.0.0.1 -carddav-port "$CARDDAV_PORT" || true

# --- Start calendar bridge ---
export PCB_PROVIDER=proton
export PCB_BIND_ADDRESS="127.0.0.1:$CALDAV_PORT"
export PCB_REQUIRE_TOKEN=false
start_service "calendar-bridge" "$CALENDAR_BRIDGE_BIN" || true

# --- Start rclone WebDAV ---
start_service "rclone-webdav" "$RCLONE_BIN" serve webdav \
    "${RCLONE_REMOTE}:" \
    --addr "127.0.0.1:$WEBDAV_PORT" \
    --vfs-cache-mode full || true

echo ""
echo -e "${PURPLE}============================================${NC}"
echo " Services:"
echo "   IMAP:    127.0.0.1:$IMAP_PORT"
echo "   SMTP:    127.0.0.1:$SMTP_PORT"
echo "   CardDAV: 127.0.0.1:$CARDDAV_PORT"
echo "   CalDAV:  127.0.0.1:$CALDAV_PORT"
echo "   WebDAV:  127.0.0.1:$WEBDAV_PORT"
echo ""
echo " Logs: $LOG_DIR/"
echo " Press Ctrl+C to stop all."
echo -e "${PURPLE}============================================${NC}"

# Wait for any child to exit
if [ ${#PIDS[@]} -eq 0 ]; then
    echo -e "${RED}No services started. Check prerequisites above.${NC}"
    exit 1
fi

wait -n 2>/dev/null || true
echo -e "${RED}A service exited unexpectedly. Check logs in $LOG_DIR/${NC}"
cleanup
