# Dashboard — Multi-stage build
# Produces a minimal image with just the Go binary + docker compose CLI.

FROM golang:1.22-alpine AS builder
WORKDIR /build
COPY go.mod ./
# No external dependencies — skip go mod download
COPY *.go ./
COPY templates/ ./templates/
RUN CGO_ENABLED=0 go build -o dashboard .

FROM alpine:3.20
RUN apk add --no-cache docker-cli docker-cli-compose
WORKDIR /app
COPY --from=builder /build/dashboard /app/dashboard
EXPOSE 8080
ENTRYPOINT ["/app/dashboard"]
