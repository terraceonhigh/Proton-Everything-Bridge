# Proton Mail Bridge container (pre-built .deb via Rosetta)
#
# Provides IMAP on :1143 and SMTP on :1025
# Recycled from: desktop/data/protonmail-bridge.service
#
# Proton only publishes amd64 packages, so this image is forced to
# linux/amd64 and runs under Rosetta on Apple Silicon.
#
# IMPORTANT: After first start, you must log in interactively:
#   docker compose exec proton-mail-bridge protonmail-bridge --cli
#   > login
#   > (enter your Proton credentials)
#   > info
#   > (note the bridge password for your email client)

FROM --platform=linux/amd64 ubuntu:24.04

ARG BRIDGE_VERSION=3.22.0

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        netcat-openbsd \
        gnome-keyring \
        libsecret-1-0 \
        pass \
        dbus-x11 && \
    rm -rf /var/lib/apt/lists/*

# Install the official .deb from GitHub releases (amd64 only).
RUN curl -fsSL \
      "https://github.com/ProtonMail/proton-bridge/releases/download/v${BRIDGE_VERSION}/protonmail-bridge_${BRIDGE_VERSION}-1_amd64.deb" \
      -o /tmp/bridge.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/bridge.deb && \
    rm -f /tmp/bridge.deb && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 1143 1025

# Recycled from data/protonmail-bridge.service: ExecStart with --noninteractive
ENTRYPOINT ["protonmail-bridge", "--noninteractive"]
