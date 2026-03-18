# Proton Bridge — All-in-one container
#
# Runs all Proton bridge services in a single container:
#   - proton-mail-bridge  (IMAP :1143, SMTP :1025)
#   - proton-calendar-bridge (CalDAV :9842)
#   - rclone serve webdav (WebDAV :9844)
#
# One container per Proton account. Uses tini + bash for process management.
# Forced to linux/amd64 — runs under Rosetta on Apple Silicon.
#
# First-time setup (interactive login for each service):
#   docker compose run --rm proton-bridge protonmail-bridge --cli
#   docker compose run --rm proton-bridge proton-calendar-bridge --login
#   docker compose run --rm proton-bridge rclone config

# ── Build calendar bridge from source ──
FROM golang:1.25-alpine AS cal-builder

RUN apk add --no-cache git

WORKDIR /build
RUN git clone --depth 1 https://github.com/SevenOfNine-Labs/proton-calendar-bridge.git .
RUN go build -o /proton-calendar-bridge ./cmd/proton-calendar-bridge/...

# ── Build hydroxide from source ──
FROM golang:1.22-alpine AS hydroxide-builder

RUN apk add --no-cache git

WORKDIR /build
RUN git clone --depth 1 https://github.com/emersion/hydroxide.git .
RUN go build -o /hydroxide ./cmd/hydroxide

# ── Runtime ──
FROM --platform=linux/amd64 ubuntu:24.04

ARG BRIDGE_VERSION=3.22.0
ARG RCLONE_VERSION=1.68.2

RUN apt-get update && \
    apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        netcat-openbsd \
        wget \
        unzip \
        tini \
        gnome-keyring \
        libsecret-1-0 \
        pass \
        dbus-x11 && \
    rm -rf /var/lib/apt/lists/*

# Install Proton Mail Bridge (.deb from GitHub releases)
RUN curl -fsSL \
      "https://github.com/ProtonMail/proton-bridge/releases/download/v${BRIDGE_VERSION}/protonmail-bridge_${BRIDGE_VERSION}-1_amd64.deb" \
      -o /tmp/bridge.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/bridge.deb && \
    rm -f /tmp/bridge.deb && \
    rm -rf /var/lib/apt/lists/*

# Install rclone
RUN curl -fsSL \
      "https://github.com/rclone/rclone/releases/download/v${RCLONE_VERSION}/rclone-v${RCLONE_VERSION}-linux-amd64.deb" \
      -o /tmp/rclone.deb && \
    apt-get update && \
    apt-get install -y --no-install-recommends /tmp/rclone.deb && \
    rm -f /tmp/rclone.deb && \
    rm -rf /var/lib/apt/lists/*

# Copy Go binaries from build stages
COPY --from=cal-builder /proton-calendar-bridge /usr/local/bin/proton-calendar-bridge
COPY --from=hydroxide-builder /hydroxide /usr/local/bin/hydroxide

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 1143 1025 9842 9844 8080

ENTRYPOINT ["tini", "--", "/entrypoint.sh"]
