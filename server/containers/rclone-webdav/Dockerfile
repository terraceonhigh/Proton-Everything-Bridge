# rclone WebDAV Server container
#
# Provides WebDAV on :9844 for Proton Drive file access.
# Recycled from: data/proton-drive-bridge@.service
#
# Key change from desktop version:
#   BEFORE (desktop):  rclone mount proton: ~/ProtonDrive --vfs-cache-mode full
#   AFTER  (server):   rclone serve webdav proton: --addr 0.0.0.0:9844 --vfs-cache-mode full
#
# IMPORTANT: rclone must be configured with a 'proton:' remote before use.
# Run interactively to set up:
#   docker compose run --rm rclone-webdav config
#
# Or copy an existing rclone.conf into the rclone_config volume.

FROM rclone/rclone:latest

RUN apk add --no-cache wget

EXPOSE 9844

# Recycled from data/proton-drive-bridge@.service ExecStart,
# changed from FUSE mount to WebDAV server for network access
CMD ["serve", "webdav", "proton:", \
     "--addr", "0.0.0.0:9844", \
     "--vfs-cache-mode", "full", \
     "--vfs-cache-max-age", "1h"]
