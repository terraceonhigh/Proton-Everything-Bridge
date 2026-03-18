#!/usr/bin/env bash
# nuke.sh — Tear down ALL Proton bridge services, volumes, and networks.
# Usage: ./nuke.sh
set -euo pipefail

cd "$(dirname "$0")"

echo "=== Stopping user stacks ==="
for project in $(docker compose ls -q 2>/dev/null | grep '^user-'); do
    echo "  Removing $project ..."
    docker compose -p "$project" -f docker-compose.user.yml down -v --remove-orphans 2>/dev/null || true
done

echo "=== Stopping shared infrastructure ==="
docker compose -f docker-compose.caddy.yml down -v --remove-orphans 2>/dev/null || true

echo "=== Removing stale containers ==="
docker ps -a --filter "label=com.docker.compose.project" --format '{{.Names}}' \
    | grep -E '^(user-|proton-)' \
    | xargs -r docker rm -f 2>/dev/null || true

echo "=== Removing proton-shared network ==="
docker network rm proton-shared 2>/dev/null || true

echo "=== Done. Everything nuked. ==="
echo ""
echo "To start fresh:"
echo "  docker network create proton-shared"
echo "  docker compose -f docker-compose.caddy.yml up -d --build"
