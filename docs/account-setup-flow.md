# Proton Account Setup Flow

## Prerequisites

Before adding a Proton account in GNOME Settings, ensure the following
services are available:

### Proton Mail
1. Install **Proton Mail Bridge** from https://proton.me/mail/bridge
2. Start the bridge: `systemctl --user start protonmail-bridge`
3. Log in via the bridge UI and note the generated app password

### Proton Drive
1. Install **rclone**: `sudo apt install rclone` (or your distro's package manager)
2. Configure the Proton remote: `rclone config create proton protondrive`
3. Start the FUSE mount: `systemctl --user start proton-drive-bridge@$USER`

### Proton Calendar
1. Build and install **proton-calendar-bridge** from the submodule
2. Start the bridge: `systemctl --user start proton-calendar-bridge`
3. CalDAV will be available at `http://127.0.0.1:9842/caldav/`

## Adding the Account

1. Open **GNOME Settings** → **Online Accounts**
2. Select **Proton Mail**, **Proton Drive**, or **Proton Calendar**
3. Follow the on-screen prompts (account setup UI is under development)

## Service Endpoints

| Service  | Protocol | Endpoint                          |
|----------|----------|-----------------------------------|
| Mail     | IMAP     | `127.0.0.1:1143`                  |
| Mail     | SMTP     | `127.0.0.1:1025`                  |
| Drive    | FUSE     | `~/ProtonDrive`                   |
| Calendar | CalDAV   | `http://127.0.0.1:9842/caldav/`   |

## Troubleshooting

- **Mail not syncing**: Check that `protonmail-bridge` is running
  (`systemctl --user status protonmail-bridge`)
- **Drive not mounting**: Verify rclone is installed and the remote is
  configured (`rclone listremotes | grep proton`)
- **Calendar empty**: Ensure `proton-calendar-bridge` is running and
  accessible on port 9842
