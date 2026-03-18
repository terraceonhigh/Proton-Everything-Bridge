# Claude Code Instructions

## Project Overview

This repo provides open-standard bridges for Proton services (Mail, Calendar,
Drive) plus a GNOME Online Accounts desktop plugin. The goal is to make Proton
work with any CalDAV/IMAP/WebDAV client.

## Current State (as of last session)

We stripped all Docker/server infrastructure and went back to basics. The repo
now contains:

- **Three bridge submodules** (uninitialized — need `git submodule update --init`):
  - `proton-mail-bridge/` → fork of official ProtonMail/proton-bridge
  - `proton-calendar-bridge/` → fork of SevenOfNine-Labs/proton-calendar-bridge
  - `proton-drive-bridge/` → Go wrapper around rclone's protondrive backend
- **GNOME desktop plugin** in `desktop/` (GOA providers in C, meson build)
- **README.md** with manual build/run instructions for each bridge
- **PROJECT_DESIGN.md** with architecture notes

## Next Task: Build the bridges natively on Apple Silicon Mac

The user wants all three bridges building and running as native binaries on an
M-series Mac (arm64). No Docker. No containers. Proton accounts have NOT been
configured yet — the user will handle authentication themselves after the
bridges are built.

### What needs to happen

1. **Initialize submodules**: `git submodule update --init --recursive`

2. **proton-mail-bridge** (highest priority):
   - Fork of official Proton Mail Bridge (C/C++/Go hybrid, uses `make`)
   - Build command: `make build-nogui`
   - May need macOS-specific deps (libsecret → Keychain, no libfido2 on mac)
   - Target: produce a `bridge` binary that runs `--cli` and `--noninteractive`
   - Ports: IMAP :1143, SMTP :1025

3. **proton-calendar-bridge** (Go, straightforward):
   - Requires Go 1.25+
   - Build: `go build -o proton-calendar-bridge ./cmd/proton-calendar-bridge/...`
   - First run: `./proton-calendar-bridge --login`
   - Normal run: `./proton-calendar-bridge` (CalDAV on :9842)
   - The terraceonhigh fork has: GPL-2.0 headers, logrus logging, golangci config

4. **proton-drive-bridge** (Go, wraps rclone):
   - Requires Go 1.22+ and rclone installed at runtime
   - Build: `go build -o proton-drive-bridge ./cmd/proton-drive-bridge/...`
   - This is a FUSE mount manager, not a server — it mounts Proton Drive at ~/ProtonDrive
   - Needs macFUSE or similar on macOS
   - Alternative: just use `rclone serve webdav proton:` directly (no FUSE needed)

### Platform notes

- **Apple Silicon (arm64)**: All Go code compiles natively. The mail bridge
  has C dependencies that may need Homebrew packages.
- **Rosetta**: Available if any dependency only ships x86_64 binaries.
- **Go version**: Install Go 1.25+ (calendar bridge requires it). Use
  `brew install go` or goenv.
- **rclone**: `brew install rclone` for drive support.

### What NOT to do

- Do not create Docker files, compose files, or container infrastructure
- Do not build a web dashboard or multi-user system
- Do not handle Proton authentication — the user will do this themselves
- Do not modify the desktop/ GNOME plugin code (separate task)
- Keep it simple — just get the binaries building

## Design Principles

1. **Maximum Recycling**: Wrap existing tools, don't reinvent
2. **No New Crypto**: Bridges handle all Proton encryption
3. **Open Standards**: CalDAV, CardDAV, WebDAV, IMAP/SMTP
