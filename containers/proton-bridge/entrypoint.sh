#!/usr/bin/env bash
set -euo pipefail

# Set up data directories — symlink /data subdirs to where each service expects config
mkdir -p /data/{protonmail/bridge-v3,protonmail-cache/bridge-v3,proton-calendar-bridge,rclone,rclone-cache,hydroxide}
mkdir -p /root/.config /root/.cache /config

ln -sfn /data/protonmail       /root/.config/protonmail
ln -sfn /data/protonmail-cache /root/.cache/protonmail
ln -sfn /data/proton-calendar-bridge /root/.config/proton-calendar-bridge
ln -sfn /data/rclone           /config/rclone
ln -sfn /data/rclone-cache     /root/.cache/rclone
ln -sfn /data/hydroxide        /root/.config/hydroxide

# If called with arguments, pass through (for interactive login commands)
if [ $# -gt 0 ]; then
  exec "$@"
fi

# Start all bridges in background
protonmail-bridge --noninteractive &
proton-calendar-bridge &
rclone serve webdav proton: \
  --addr 0.0.0.0:9844 \
  --vfs-cache-mode minimal \
  --vfs-cache-max-age 30m \
  --transfers 2 --checkers 2 --buffer-size 16M &

# Exit when any child exits — Docker restart policy handles recovery
wait -n
