# hydroxide CardDAV Bridge container (EXPERIMENTAL)
#
# Provides CardDAV on :8080 for Proton contacts sync.
# Uses unofficial Proton API — may break if Proton changes their API.
#
# Based on: https://github.com/emersion/hydroxide
#
# IMPORTANT: You must authenticate before first use:
#   docker compose exec hydroxide hydroxide auth <proton-username>
#   (enter your Proton password when prompted)

FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git

WORKDIR /build

RUN git clone --depth 1 https://github.com/emersion/hydroxide.git .

RUN go build -o /hydroxide ./cmd/hydroxide

# ── Runtime ──
FROM alpine:3.20

RUN apk add --no-cache ca-certificates netcat-openbsd

COPY --from=builder /hydroxide /usr/local/bin/hydroxide

EXPOSE 8080

# hydroxide serves IMAP, SMTP, and CardDAV; we only need CardDAV here
ENTRYPOINT ["hydroxide", "carddav"]
