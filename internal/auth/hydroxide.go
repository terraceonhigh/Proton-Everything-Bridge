package auth

import (
	"context"
	"fmt"

	"github.com/emersion/hydroxide/auth"
	"github.com/emersion/hydroxide/protonmail"
)

// HydroxideProvisioner provisions hydroxide credentials from raw Proton login info.
type HydroxideProvisioner struct{}

// HydroxideResult contains the result of provisioning hydroxide credentials.
type HydroxideResult struct {
	BridgePassword string
	Username       string
}

// Provision authenticates with Proton via hydroxide's API and saves credentials.
// This replicates the "hydroxide auth" flow using exported hydroxide packages.
func (h *HydroxideProvisioner) Provision(ctx context.Context, creds Credentials) (*HydroxideResult, error) {
	c := &protonmail.Client{
		RootURL:    "https://mail.proton.me/api",
		AppVersion: "Other",
	}

	// SRP authentication
	authInfo, err := c.AuthInfo(creds.Username)
	if err != nil {
		return nil, fmt.Errorf("hydroxide auth info: %w", err)
	}

	a, err := c.Auth(creds.Username, creds.Password, authInfo)
	if err != nil {
		return nil, fmt.Errorf("hydroxide auth: %w", err)
	}

	// Handle 2FA
	if a.TwoFactor.Enabled != 0 {
		if a.TwoFactor.TOTP != 1 {
			return nil, fmt.Errorf("only TOTP 2FA is supported")
		}
		if creds.TOTPCode == "" {
			return nil, fmt.Errorf("2FA is enabled but no TOTP code provided")
		}
		scope, err := c.AuthTOTP(creds.TOTPCode)
		if err != nil {
			return nil, fmt.Errorf("hydroxide 2FA: %w", err)
		}
		a.Scope = scope
	}

	// Determine mailbox password
	mailboxPassword := creds.Password
	if a.PasswordMode == protonmail.PasswordTwo {
		if creds.MailboxPassword == "" {
			return nil, fmt.Errorf("dual-password account but no mailbox password provided")
		}
		mailboxPassword = creds.MailboxPassword
	}

	// Unlock keys
	keySalts, err := c.ListKeySalts()
	if err != nil {
		return nil, fmt.Errorf("hydroxide key salts: %w", err)
	}

	_, err = c.Unlock(a, keySalts, mailboxPassword)
	if err != nil {
		return nil, fmt.Errorf("hydroxide unlock: %w", err)
	}

	// Generate and save bridge password
	secretKey, bridgePassword, err := auth.GeneratePassword()
	if err != nil {
		return nil, fmt.Errorf("hydroxide generate password: %w", err)
	}

	err = auth.EncryptAndSave(&auth.CachedAuth{
		Auth:            *a,
		LoginPassword:   creds.Password,
		MailboxPassword: mailboxPassword,
		KeySalts:        keySalts,
	}, creds.Username, secretKey)
	if err != nil {
		return nil, fmt.Errorf("hydroxide save: %w", err)
	}

	return &HydroxideResult{
		BridgePassword: bridgePassword,
		Username:       creds.Username,
	}, nil
}
