# MASTER BUILD PLAN: Proton Services Integration for GNOME Online Accounts

## 1. Template Audit Results

### GoaImapSmtpProvider (Mail Template)
- **File**: `src/goabackend/goaimapsmtpprovider.{c,h}` in upstream GOA 3.50.4
- **Parent class**: `GoaProvider` (direct subclass)
- **Type string**: `"imap_smtp"`
- **Features**: `GOA_PROVIDER_FEATURE_MAIL`
- **Auth model**: Direct credential verification against IMAP (port 993/143) and SMTP (port 465/587) using `GoaMailClient` + `GoaImapAuthLogin` + `GoaSmtpAuth`
- **Key internal includes**: `goamailclient.h`, `goaimapauthlogin.h`, `goasmtpauth.h`, `goamailconfig.h`
- **Mandatory vfuncs overridden**:
  - `get_provider_type`, `get_provider_name`, `get_provider_group`, `get_provider_features`, `get_provider_icon`
  - `build_object` — reconstructs account from GKeyFile
  - `add_account` — multi-page async dialog (email → IMAP → SMTP pages)
  - `refresh_account` — re-checks credentials
  - `show_account` — read-only info widget
  - `ensure_credentials_sync` — validates IMAP+SMTP creds synchronously

### GoaOwncloudProvider (Drive/Files Template)
- **File**: `src/goabackend/goaowncloudprovider.{c,h}` in upstream GOA 3.50.4
- **Parent class**: `GoaWebDavProvider` (intermediate, itself a `GoaProvider` subclass)
- **Type string**: `"owncloud"` (display name: `"Nextcloud"`)
- **Features**: `GOA_PROVIDER_FEATURE_CALENDAR | GOA_PROVIDER_FEATURE_CONTACTS | GOA_PROVIDER_FEATURE_FILES`
- **Auth model**: Nextcloud Login Flow v2 — browser-redirect OAuth-like flow, polls `index.php/login/v2` every 5s via libsoup
- **Key internal includes**: `goawebdavprovider.h`, `goawebdavprovider-priv.h`, `libsoup/soup.h`, `json-glib/json-glib.h`
- **Mandatory vfuncs overridden**:
  - `get_provider_type`, `get_provider_name`, `get_provider_group`, `get_provider_features`, `get_provider_icon`
  - `build_object`, `add_account`, `refresh_account`
  - `migrate_account` (migration of old-format URIs)
  - Does **not** override `show_account` or `ensure_credentials_sync` (inherited from `GoaWebDavProvider`)

---

## 2. Files to Create

### A. Proton Mail Provider (IMAP/SMTP Wrapper)

| File | Action | Description |
|------|--------|-------------|
| `src/goabackend/goaprotonmailprovider.h` | **CREATE** | Header declaring `GoaProtonMailProvider` as final type extending `GoaProvider` |
| `src/goabackend/goaprotonmailprovider.c` | **CREATE** | Implementation cloned from `GoaImapSmtpProvider` with hardcoded `127.0.0.1` and bridge port/password scraping |
| `src/goabackend/goaprotonbridge.h` | **CREATE** | Header for bridge helper (port + app-password discovery) |
| `src/goabackend/goaprotonbridge.c` | **CREATE** | Implementation: runs `protonmail-bridge --cli`, parses output for IMAP/SMTP ports and app password |

**Strategy**:
1. Copy `GoaImapSmtpProvider` skeleton.
2. In `build_object()`: hard-code `ImapHost=127.0.0.1`, `SmtpHost=127.0.0.1`.
3. Add a `goa_proton_bridge_get_credentials()` helper that runs `protonmail-bridge --cli status` (or the appropriate subcommand) and scrapes the dynamic IMAP port, SMTP port, and generated app-password.
4. In `add_account()`: check for bridge binary existence (`g_find_program_in_path("protonmail-bridge")`); if absent, show a `GtkAlertDialog` directing the user to install/start it.
5. In `ensure_credentials_sync()`: call `goa_proton_bridge_get_credentials()` to refresh port/password before attempting IMAP/SMTP validation.
6. Remove the mail auto-discovery UI (no DNS MX lookup needed — server is always localhost).

**Provider constants**:
```c
#define GOA_PROTON_MAIL_NAME       "proton_mail"
#define GOA_PROTON_MAIL_IMAP_HOST  "127.0.0.1"
#define GOA_PROTON_MAIL_SMTP_HOST  "127.0.0.1"
```

---

### B. Proton Drive Provider (FUSE/rclone Mount)

| File | Action | Description |
|------|--------|-------------|
| `src/goabackend/goaprotondriveprovider.h` | **CREATE** | Header declaring `GoaProtonDriveProvider` as final type extending `GoaWebDavProvider` |
| `src/goabackend/goaprotondriveprovider.c` | **CREATE** | Implementation recycling `GoaOwncloudProvider` skeleton, replacing LoginFlow v2 with rclone auth |
| `src/goabackend/goaprotonrclone.h` | **CREATE** | Header for rclone helper (configure, mount, unmount) |
| `src/goabackend/goaprotonrclone.c` | **CREATE** | Implementation: wraps `rclone config`, `rclone mount`, stores credentials in GNOME Keyring |

**Strategy**:
1. Copy `GoaOwncloudProvider` skeleton.
2. Replace LoginFlow v2 with an `add_account()` dialog that:
   - Prompts for Proton credentials (username + password).
   - Calls `goa_proton_rclone_configure()` to run `rclone config create proton protondrive user=... pass=...` (password obscured via `rclone obscure`).
   - Stores the rclone remote name + config path in GNOME Keyring via `libsecret`.
3. In `build_object()`: set up a Files interface pointing to the rclone FUSE mount point (`~/ProtonDrive`).
4. Spawn the rclone mount as a subprocess (or delegate to the systemd unit in `proton-drive-bridge/setup-proton-mount.sh`).
5. In `ensure_credentials_sync()`: verify the mount point is accessible (`g_file_query_exists()`).
6. Check for `rclone` binary at startup; show error dialog if absent.

**Provider constants**:
```c
#define GOA_PROTON_DRIVE_NAME        "proton_drive"
#define GOA_PROTON_DRIVE_MOUNT_POINT "ProtonDrive"   /* relative to $HOME */
#define GOA_PROTON_DRIVE_RCLONE_REMOTE "proton"
```

---

### C. Proton Calendar Provider (CalDAV Bridge)

| File | Action | Description |
|------|--------|-------------|
| `src/goabackend/goaprotoncalendarprovider.h` | **CREATE** | Header declaring `GoaProtonCalendarProvider` as final type extending `GoaProvider` (or `GoaCalDavProvider` if accessible) |
| `src/goabackend/goaprotoncalendarprovider.c` | **CREATE** | Implementation pointing CalDAV at `http://127.0.0.1:9842/caldav/` |

**Strategy**:
1. Modelled on `GoaCalDavProvider`.
2. In `build_object()`: set `CalDavUri=http://127.0.0.1:9842/caldav/`.
3. In `add_account()`: check for the `proton-calendar-bridge` binary; if not running, start it.
4. The `proton-calendar-bridge` submodule already exposes a CalDAV endpoint at port 9842 (see `proton-calendar-bridge/DEVELOPMENT_PLAN.md`).
5. In `ensure_credentials_sync()`: issue a `PROPFIND http://127.0.0.1:9842/caldav/` and verify a 207 response.

**Provider constants**:
```c
#define GOA_PROTON_CALENDAR_NAME     "proton_calendar"
#define GOA_PROTON_CALENDAR_CALDAV_URI "http://127.0.0.1:9842/caldav/"
```

---

### D. Build System Integration

| File | Action | Description |
|------|--------|-------------|
| `src/goabackend/meson.build` | **MODIFY** | Add the 8 new `.c` files to the `goabackend_sources` array |
| `src/goabackend/goabackend.h` | **MODIFY** | Add `#include` directives for the 3 new provider headers |

---

## 3. Dependency Status

| Dependency | Status | Notes |
|------------|--------|-------|
| `protonmail-bridge` binary | **NOT FOUND** | Not installed on this system; must be present at runtime |
| `rclone` binary | **NOT FOUND** | Not installed; `apt install rclone` or build from source |
| `proton-mail-bridge` submodule | **PRESENT** | Go source at `proton-mail-bridge/`; must be compiled and installed |
| `proton-drive-bridge` submodule | **PRESENT** | Contains `setup-proton-mount.sh` (rclone systemd unit); rclone itself still needed |
| `proton-calendar-bridge` submodule | **PRESENT** | Go source; CalDAV endpoint on port 9842 per `DEVELOPMENT_PLAN.md` |
| `meson` build tool | **NOT INSTALLED** | Available via `apt install meson` (v1.3.2) |
| `ninja` build tool | **INSTALLED** | `ninja-build` 1.11.1 present |
| `libgoa-backend-1.0-dev` | **NOT INSTALLED** | Available via `apt install libgoa-backend-1.0-dev` (GOA 3.50.4) |
| `libglib2.0-dev` | **INSTALLED** | v2.80.0 |
| `libsecret-1-dev` | **NOT CHECKED** | Required for GNOME Keyring integration |
| `libsoup-3.0-dev` | **NOT CHECKED** | Required for HTTP in OwnCloud-derived provider |
| `json-glib-1.0-dev` | **NOT CHECKED** | Required for OwnCloud-derived provider |

---

## 4. Pre-Build Steps (One-Time Setup)

```bash
# Install build tools
sudo apt install meson libgoa-backend-1.0-dev \
  libsecret-1-dev libsoup-3.0-dev libjson-glib-dev \
  libglib2.0-dev pkg-config

# Install rclone
sudo apt install rclone
# OR: curl https://rclone.org/install.sh | sudo bash

# Build and install Proton Mail Bridge
cd proton-mail-bridge && make build && sudo cp bridge /usr/local/bin/protonmail-bridge && cd ..

# Build and install Proton Calendar Bridge
cd proton-calendar-bridge && go build ./cmd/proton-calendar-bridge/... && \
  sudo cp proton-calendar-bridge /usr/local/bin/ && cd ..
```

---

## 5. Build Commands

```bash
# Configure (from repo root, once GOA source is cloned alongside or patched in-tree)
meson setup builddir --prefix=/usr --buildtype=debugoptimized

# Compile
ninja -C builddir

# Install
sudo ninja -C builddir install
```

---

## 6. Implementation Order

1. **`goaprotonbridge.{c,h}`** — bridge helper (used by mail provider)
2. **`goaprotonmailprovider.{c,h}`** — simplest provider, validates the build chain end-to-end
3. **`goaprotonrclone.{c,h}`** — rclone helper (used by drive provider)
4. **`goaprotondriveprovider.{c,h}`** — drive provider
5. **`goaprotoncalendarprovider.{c,h}`** — calendar provider
6. **Meson + header integration** — wire everything into the build

---

## 7. Known Risks and Mitigations

| Risk | Mitigation |
|------|-----------|
| `protonmail-bridge --cli` output format changes | Parse with regex; add a version guard and fall back to a UI prompt |
| `rclone` not installed at runtime | Check in `add_account()` and `ensure_credentials_sync()`; surface a clear `GtkAlertDialog` |
| GOA source not available in-tree (only binary package installed) | Clone upstream GOA at the same version (3.50.4) and apply patches as an out-of-tree fork, or request `libgoa-backend-1.0-dev` for the headers only |
| CalDAV bridge port 9842 conflicts | Make port configurable via GSettings key |
| Proton Calendar bridge write support incomplete | `DEVELOPMENT_PLAN.md` documents the gap; ship read-only first, enable write when bridge is ready |
| >100 lines of original C per component | Each provider's custom logic (bridge scraping, rclone spawn, CalDAV check) is under 100 lines; bulk of UI boilerplate is copied from templates per the "Maximum Recycling" rule |
