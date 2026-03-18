# Proton Mail Bridge container
#
# Provides IMAP on :1143 and SMTP on :1025
# Recycled from: desktop/data/protonmail-bridge.service
#
# IMPORTANT: After first start, you must log in interactively:
#   docker compose exec proton-mail-bridge protonmail-bridge --cli
#   > login
#   > (enter your Proton credentials)
#   > info
#   > (note the bridge password for your email client)

# ── Build stage ──
FROM golang:1.24-bookworm AS builder

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        git make gcc pkg-config \
        libsecret-1-dev && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /build

RUN git clone --depth 1 https://github.com/ProtonMail/proton-bridge.git .

RUN make build-nogui

# ── Runtime ──
FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        netcat-openbsd \
        gnome-keyring \
        libsecret-1-0 \
        pass \
        dbus-x11 && \
    rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/bridge /usr/local/bin/protonmail-bridge

EXPOSE 1143 1025

# Recycled from data/protonmail-bridge.service: ExecStart with --noninteractive
ENTRYPOINT ["protonmail-bridge", "--noninteractive"]
