package auth

import (
	"context"
	"fmt"
	"log"

	"github.com/terraceonhigh/proton-everything-bridge/internal/config"
)

// Credentials holds the user's Proton login information.
type Credentials struct {
	Username        string
	Password        string
	TOTPCode        string
	MailboxPassword string // empty for single-password accounts
}

// LoginResult contains the outcomes of unified provisioning.
type LoginResult struct {
	HydroxideBridgePassword string
	CalendarSessionPath     string
	RcloneConfigPath        string
	Errors                  []string // non-fatal errors (e.g. rclone not found)
}

// UnifiedAuth orchestrates single-login provisioning across all backends.
type UnifiedAuth struct {
	cfg config.Config
}

// NewUnifiedAuth creates a new unified auth orchestrator.
func NewUnifiedAuth(cfg config.Config) *UnifiedAuth {
	return &UnifiedAuth{cfg: cfg}
}

// Login authenticates once and provisions all backend credential stores.
// Non-fatal errors (e.g. a missing binary) are collected in LoginResult.Errors
// rather than aborting the entire flow.
func (u *UnifiedAuth) Login(ctx context.Context, creds Credentials) (*LoginResult, error) {
	result := &LoginResult{}

	// 1. Provision hydroxide (IMAP + SMTP + CardDAV)
	hp := &HydroxideProvisioner{}
	hResult, err := hp.Provision(ctx, creds)
	if err != nil {
		return nil, fmt.Errorf("hydroxide login failed (required): %w", err)
	}
	result.HydroxideBridgePassword = hResult.BridgePassword
	log.Printf("Hydroxide provisioned for %s", creds.Username)

	// 2. Provision calendar bridge (CalDAV)
	// Note: full calendar provisioning requires authenticating via go-proton-api
	// to obtain session tokens (UID, AccessToken, RefreshToken). This is a
	// placeholder — Mode 3 implementation will add the go-proton-api auth call.
	if u.cfg.EnableCalDAV {
		log.Printf("Calendar bridge: manual login required (run: proton-calendar-bridge --login)")
		result.Errors = append(result.Errors,
			"Calendar bridge requires separate login (go-proton-api integration pending)")
	}

	// 3. Provision rclone (WebDAV for Drive)
	if u.cfg.EnableWebDAV {
		rp := &RcloneProvisioner{RcloneBin: u.cfg.RcloneBin}
		rResult, err := rp.Provision(creds, u.cfg.RcloneRemote)
		if err != nil {
			result.Errors = append(result.Errors, fmt.Sprintf("rclone: %v", err))
			log.Printf("rclone provisioning failed (non-fatal): %v", err)
		} else {
			result.RcloneConfigPath = rResult.ConfigPath
			log.Printf("rclone provisioned: %s", rResult.ConfigPath)
		}
	}

	return result, nil
}
