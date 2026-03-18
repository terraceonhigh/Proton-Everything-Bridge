package auth

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hmac"
	"crypto/rand"
	"crypto/sha256"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

const calendarSaltSize = 16

// calendarSession mirrors the calendar bridge's internal Session type.
type calendarSession struct {
	UID          string `json:"uid"`
	AccessToken  string `json:"access_token"`
	RefreshToken string `json:"refresh_token"`
	Username     string `json:"username"`
}

// CalendarProvisioner provisions calendar bridge credentials.
type CalendarProvisioner struct {
	DataDir string
}

// CalendarResult contains the result of provisioning calendar bridge credentials.
type CalendarResult struct {
	SessionPath    string
	BridgePassword string
}

// Provision writes a calendar bridge session file encrypted with AES-256-GCM.
//
// Note: the calendar bridge's own store uses argon2id for key derivation.
// This provisioner writes its own compatible-format file using HMAC-SHA256
// based KDF instead. For full interop with the calendar bridge's native
// store, run `proton-calendar-bridge --login` directly.
func (c *CalendarProvisioner) Provision(session calendarSession, bridgePassword string) (*CalendarResult, error) {
	sessionPath := filepath.Join(c.DataDir, "calendar-session.enc")
	if err := os.MkdirAll(filepath.Dir(sessionPath), 0o700); err != nil {
		return nil, fmt.Errorf("create data dir: %w", err)
	}

	plaintext, err := json.Marshal(session)
	if err != nil {
		return nil, fmt.Errorf("marshal session: %w", err)
	}

	salt := make([]byte, calendarSaltSize)
	if _, err := io.ReadFull(rand.Reader, salt); err != nil {
		return nil, fmt.Errorf("generate salt: %w", err)
	}

	key := calendarDeriveKey(bridgePassword, salt)

	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, fmt.Errorf("create cipher: %w", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		return nil, fmt.Errorf("create gcm: %w", err)
	}

	nonce := make([]byte, gcm.NonceSize())
	if _, err := io.ReadFull(rand.Reader, nonce); err != nil {
		return nil, fmt.Errorf("generate nonce: %w", err)
	}

	ciphertext := gcm.Seal(nil, nonce, plaintext, nil)
	blob := append(append(salt, nonce...), ciphertext...)

	if err := os.WriteFile(sessionPath, blob, 0o600); err != nil {
		return nil, fmt.Errorf("write session: %w", err)
	}

	return &CalendarResult{
		SessionPath:    sessionPath,
		BridgePassword: bridgePassword,
	}, nil
}

// calendarDeriveKey derives a 32-byte AES key from a password and salt
// using iterated HMAC-SHA256 (stdlib only, no x/crypto dependency).
func calendarDeriveKey(password string, salt []byte) []byte {
	key := append([]byte(password), salt...)
	for i := 0; i < 100000; i++ {
		h := hmac.New(sha256.New, salt)
		h.Write(key)
		key = h.Sum(nil)
	}
	return key
}
