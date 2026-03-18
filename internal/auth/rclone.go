package auth

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
)

// RcloneProvisioner provisions rclone credentials for Proton Drive.
type RcloneProvisioner struct {
	RcloneBin  string
	ConfigPath string // if empty, uses default rclone config location
}

// RcloneResult contains the result of provisioning rclone credentials.
type RcloneResult struct {
	ConfigPath string
	RemoteName string
}

// Provision writes a protondrive remote section to rclone.conf.
func (r *RcloneProvisioner) Provision(creds Credentials, remoteName string) (*RcloneResult, error) {
	configPath := r.ConfigPath
	if configPath == "" {
		configDir, err := os.UserConfigDir()
		if err != nil {
			return nil, fmt.Errorf("config dir: %w", err)
		}
		configPath = filepath.Join(configDir, "rclone", "rclone.conf")
	}

	if err := os.MkdirAll(filepath.Dir(configPath), 0o700); err != nil {
		return nil, fmt.Errorf("create config dir: %w", err)
	}

	// Obscure the password using rclone's built-in obscure command
	obscuredPass, err := r.obscurePassword(creds.Password)
	if err != nil {
		return nil, fmt.Errorf("obscure password: %w", err)
	}

	// Build the config section
	section := fmt.Sprintf("\n[%s]\ntype = protondrive\nuser = %s\npass = %s\n",
		remoteName, creds.Username, obscuredPass)

	if creds.MailboxPassword != "" {
		obscuredMailbox, err := r.obscurePassword(creds.MailboxPassword)
		if err != nil {
			return nil, fmt.Errorf("obscure mailbox password: %w", err)
		}
		section += fmt.Sprintf("mailbox_password = %s\n", obscuredMailbox)
	}

	// Append to config file (or create it)
	f, err := os.OpenFile(configPath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0o600)
	if err != nil {
		return nil, fmt.Errorf("open config: %w", err)
	}
	defer f.Close()

	if _, err := f.WriteString(section); err != nil {
		return nil, fmt.Errorf("write config: %w", err)
	}

	return &RcloneResult{
		ConfigPath: configPath,
		RemoteName: remoteName,
	}, nil
}

func (r *RcloneProvisioner) obscurePassword(password string) (string, error) {
	bin := r.RcloneBin
	if bin == "" {
		bin = "rclone"
	}

	cmd := exec.Command(bin, "obscure", password)
	out, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("rclone obscure: %w", err)
	}
	return strings.TrimSpace(string(out)), nil
}
