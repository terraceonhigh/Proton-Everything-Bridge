# Proton Calendar Bridge container
#
# Provides CalDAV on :9842
# Recycled from: data/proton-calendar-bridge.service
#
# The calendar bridge is built from the proton-calendar-bridge submodule.
# If building from the repo root, use:
#   docker compose build proton-calendar-bridge

FROM golang:1.22-alpine AS builder

RUN apk add --no-cache git

WORKDIR /build

# Clone or copy the calendar bridge source
# Using the upstream repo; can be replaced with local submodule copy
RUN git clone --depth 1 https://github.com/nicstruc/proton-calendar-bridge.git . || \
    git clone --depth 1 https://github.com/SevenOfNine-Labs/proton-calendar-bridge.git .

RUN go build -o /proton-calendar-bridge ./cmd/proton-calendar-bridge/...

# ── Runtime ──
FROM alpine:3.20

RUN apk add --no-cache ca-certificates netcat-openbsd

COPY --from=builder /proton-calendar-bridge /usr/local/bin/proton-calendar-bridge

EXPOSE 9842

# Recycled from data/proton-calendar-bridge.service: ExecStart
ENTRYPOINT ["proton-calendar-bridge"]
