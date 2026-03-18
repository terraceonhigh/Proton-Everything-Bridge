#!/usr/bin/env bash
# healthcheck.sh — Verify all Proton bridge services are responding
#
# Recycled from: desktop/src/goabackend/goaprotonauth.c
# The original C code used GSocket TCP probes to check bridge availability.
# This script implements the same pattern in bash for Docker health checks.
#
# Original C functions and their equivalents here:
#   goa_proton_bridge_is_running()          → check IMAP on :1143
#   goa_proton_calendar_bridge_is_running() → check CalDAV on :9842
#   (new for server)                        → check WebDAV on :9844
#   (new for server)                        → check CardDAV on :8080
#
# Usage:
#   ./healthcheck.sh              — check all services
#   ./healthcheck.sh --service X  — check specific service

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

# TCP port probe — equivalent to goa_proton_bridge_is_running() in goaprotonauth.c
check_port() {
    local host="$1" port="$2" label="$3"
    if nc -z -w2 "$host" "$port" 2>/dev/null; then
        printf "  ${GREEN}✓${NC}  %-25s %s:%s\n" "$label" "$host" "$port"
        return 0
    else
        printf "  ${RED}✗${NC}  %-25s %s:%s not responding\n" "$label" "$host" "$port"
        return 1
    fi
}

FAILED=0
SERVICE="${2:-all}"

case "$SERVICE" in
    all)
        echo "Proton DAV Server — Health Check"
        echo ""
        check_port proton-mail-bridge     1143 "IMAP (Mail Bridge)"     || FAILED=$((FAILED + 1))
        check_port proton-mail-bridge     1025 "SMTP (Mail Bridge)"     || FAILED=$((FAILED + 1))
        check_port proton-calendar-bridge 9842 "CalDAV (Calendar)"      || FAILED=$((FAILED + 1))
        check_port rclone-webdav          9844 "WebDAV (Drive)"         || FAILED=$((FAILED + 1))
        check_port hydroxide              8080 "CardDAV (Contacts)"     || FAILED=$((FAILED + 1))
        echo ""
        if [ "$FAILED" -gt 0 ]; then
            echo "$FAILED service(s) not responding."
            exit 1
        else
            echo "All services healthy."
        fi
        ;;
    imap|mail)     check_port proton-mail-bridge     1143 "IMAP" || exit 1 ;;
    smtp)          check_port proton-mail-bridge     1025 "SMTP" || exit 1 ;;
    caldav|cal)    check_port proton-calendar-bridge 9842 "CalDAV" || exit 1 ;;
    webdav|drive)  check_port rclone-webdav          9844 "WebDAV" || exit 1 ;;
    carddav|card)  check_port hydroxide              8080 "CardDAV" || exit 1 ;;
    *)             echo "Unknown service: $SERVICE"; exit 1 ;;
esac
