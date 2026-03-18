# Proton Mail Bridge container (pre-built)
#
# Provides IMAP on :1143 and SMTP on :1025
# Recycled from: desktop/data/protonmail-bridge.service
#
# Uses the official .deb package from Proton instead of compiling from source.
# This cuts build time from ~10 minutes to ~30 seconds.
#
# IMPORTANT: After first start, you must log in interactively:
#   docker compose exec proton-mail-bridge protonmail-bridge --cli
#   > login
#   > (enter your Proton credentials)
#   > info
#   > (note the bridge password for your email client)

FROM ubuntu:24.04

ARG BRIDGE_VERSION=3.16.0-1
ARG TARGETARCH

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

# Download and install the official .deb package from Proton's repo.
# Architecture is mapped: amd64 stays amd64, arm64 stays arm64.
RUN curl -fsSL \
      "https://proton.me/download/bridge/protonmail-bridge_${BRIDGE_VERSION}_${TARGETARCH}.deb" \
      -o /tmp/bridge.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/bridge.deb && \
    rm -f /tmp/bridge.deb && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 1143 1025

# Recycled from data/protonmail-bridge.service: ExecStart with --noninteractive
ENTRYPOINT ["protonmail-bridge", "--noninteractive"]
