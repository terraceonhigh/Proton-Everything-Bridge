# Proton Mail Bridge container
#
# Provides IMAP on :1143 and SMTP on :1025
# Recycled from: data/protonmail-bridge.service
#
# IMPORTANT: After first start, you must log in interactively:
#   docker compose exec proton-mail-bridge protonmail-bridge --cli
#   > login
#   > (enter your Proton credentials)
#   > info
#   > (note the bridge password for your email client)

FROM ubuntu:24.04

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        netcat-openbsd \
        gnome-keyring \
        pass \
        dbus-x11 && \
    rm -rf /var/lib/apt/lists/*

# Download and install Proton Mail Bridge
# The URL redirects to the latest stable release
RUN curl -fSL -o /tmp/bridge.deb \
        "https://proton.me/download/bridge/protonmail-bridge_linux_x86.deb" && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/bridge.deb && \
    rm -f /tmp/bridge.deb && \
    rm -rf /var/lib/apt/lists/*

EXPOSE 1143 1025

# Recycled from data/protonmail-bridge.service: ExecStart with --noninteractive
ENTRYPOINT ["protonmail-bridge", "--noninteractive"]
