#!/usr/bin/env bash
# nuke.sh — Tear down ALL Proton bridge services, volumes, and networks,
#            then rebuild and restart everything fresh.
# Usage: ./nuke.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Stopping everything ==="
docker compose down -v --remove-orphans 2>/dev/null || true

# Also clean up old server-mode stacks if they exist
for project in $(docker compose ls -q 2>/dev/null | grep '^user-'); do
    echo "  Removing old user stack: $project ..."
    docker compose -p "$project" -f docker-compose.user.yml down -v --remove-orphans 2>/dev/null || true
done
docker compose -f docker-compose.caddy.yml down -v --remove-orphans 2>/dev/null || true
docker network rm proton-shared 2>/dev/null || true

echo "=== Removing stale containers ==="
docker ps -a --filter "label=com.docker.compose.project" --format '{{.Names}}' \
    | grep -E '^(user-|proton-)' \
    | xargs -r docker rm -f 2>/dev/null || true

echo "=== Rebuilding fresh ==="
docker compose build --no-cache
docker compose up -d

echo ""
echo "=== Done. Services running on localhost: ==="
echo "  IMAP   127.0.0.1:1143"
echo "  SMTP   127.0.0.1:1025"
echo "  CalDAV 127.0.0.1:9842"
echo "  WebDAV 127.0.0.1:9844"
echo ""
echo "For CardDAV (experimental):"
echo "  docker compose --profile carddav up -d"
