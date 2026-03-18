#!/usr/bin/env bash
# nuke.sh — Tear down ALL Proton bridge services, volumes, and networks.
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

echo ""
echo "=== Nuked. Everything is gone. ==="
echo ""
echo "To start fresh, run:"
echo "  bash install-server.sh"
