# Account Setup Guide

## Server Mode

### 1. Install the server

**Linux / macOS:**
```bash
bash install-server.sh
```

**Windows** (PowerShell):
```powershell
.\install-server.ps1
```

The installer will:
- Install Docker if needed (Docker Desktop on Windows/macOS, Docker Engine on Linux)
- Ask you to choose an access mode (localhost, LAN, whitelist, or internet)
- Set up authentication credentials
- Start the server

### Windows prerequisites

- **Windows 10 25H2** or later
- **Docker Desktop** with WSL2 backend (the installer can install this via winget)
- **PowerShell execution policy**: If you get an execution policy error, run once:
  ```powershell
  Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned
  ```
- Bridge login commands (step 3 below) work from PowerShell or Windows Terminal

### 2. Add an account

Open **https://your-domain/** in your browser and log in with the credentials
you set during install.

Click **[+ Add Account]** and enter a name (e.g., `alice`). The server will
spin up an isolated bridge container for that account.

### 3. Authenticate the bridges

Click **[Bridge Login]** on the account card to see the CLI commands. SSH into
your server and run them:

**Mail Bridge:**
```bash
docker compose -p user-alice \
  -f docker-compose.user.yml \
  run --rm proton-bridge protonmail-bridge --cli
> login
> (enter Proton credentials)
> info   (note the bridge password)
> exit
```

**Drive (rclone):**
```bash
docker compose -p user-alice \
  -f docker-compose.user.yml \
  run --rm proton-bridge rclone config
> n      (new remote)
> proton (name)
> protondrive (type)
> (follow Proton login prompts)
```

**Calendar Bridge:**
```bash
docker compose -p user-alice \
  -f docker-compose.user.yml \
  run --rm proton-bridge proton-calendar-bridge --login
```

**Contacts (experimental):**
```bash
docker compose -p user-alice \
  -f docker-compose.user.yml \
  run --rm proton-bridge hydroxide auth alice@proton.me
```

### 4. Configure your apps

Click **[Setup Instructions]** on the account card to see endpoint URLs.

#### Service Endpoints

| Service | Protocol | Endpoint |
|---------|----------|----------|
| Calendar | CalDAV | `https://your-domain/users/alice/caldav/` |
| Contacts | CardDAV | `https://your-domain/users/alice/carddav/` |
| Files | WebDAV | `https://your-domain/users/alice/webdav/` |
| Mail | IMAP | `your-domain:993` |
| Mail | SMTP | `your-domain:465` |

#### Client-specific instructions

**iOS / macOS:**
Settings → Calendar → Add Account → Other → CalDAV → Server: `your-domain`

**Thunderbird:**
New Calendar → Network → CalDAV → `https://your-domain/users/alice/caldav/`

**DAVx5 (Android):**
Base URL: `https://your-domain/users/alice/caldav/`

**Windows (WebDAV drive):**
Map Network Drive → `https://your-domain/users/alice/webdav/`

**GNOME / Nautilus:**
Other Locations → Connect to Server → `davs://your-domain/users/alice/webdav/`

### Adding more accounts

Repeat steps 2-4 for each Proton account. Each account gets its own isolated
containers and endpoints.

---

## Desktop Mode (GNOME)

### Prerequisites

Install the required bridges before adding accounts in GNOME Settings.

#### Proton Mail
1. Install **Proton Mail Bridge** from https://proton.me/mail/bridge
2. Start the bridge: `systemctl --user start protonmail-bridge`
3. Log in via the bridge UI and note the generated app password

#### Proton Drive
1. Install **rclone**: `sudo apt install rclone`
2. Configure the Proton remote: `rclone config create proton protondrive`
3. Start the mount: `systemctl --user start proton-drive-bridge@$USER`

#### Proton Calendar
1. Build **proton-calendar-bridge** from the submodule
2. Start: `systemctl --user start proton-calendar-bridge`
3. CalDAV available at `http://127.0.0.1:9842/caldav/`

### Adding the account

1. Open **GNOME Settings** → **Online Accounts**
2. Select **Proton Mail**, **Proton Drive**, or **Proton Calendar**
3. Follow the on-screen prompts

### Desktop endpoints

| Service | Protocol | Endpoint |
|---------|----------|----------|
| Mail | IMAP | `127.0.0.1:1143` |
| Mail | SMTP | `127.0.0.1:1025` |
| Drive | FUSE | `~/ProtonDrive` |
| Calendar | CalDAV | `http://127.0.0.1:9842/caldav/` |

---

## Troubleshooting

### Server mode

**Dashboard shows services as unhealthy:**
Bridges need to be authenticated first. Click [Bridge Login] and run the
commands.

**Can't reach the dashboard:**
```bash
bash install-server.sh --status
docker compose -f docker-compose.caddy.yml logs caddy
```

**Account containers won't start:**
```bash
docker compose -p user-alice -f docker-compose.user.yml logs
```

### Desktop mode

**Mail not syncing:**
```bash
systemctl --user status protonmail-bridge
```

**Drive not mounting:**
```bash
rclone listremotes | grep proton
systemctl --user status proton-drive-bridge@$USER
```

**Calendar empty:**
```bash
curl http://127.0.0.1:9842/caldav/
systemctl --user status proton-calendar-bridge
```
