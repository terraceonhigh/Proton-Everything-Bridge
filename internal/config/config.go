package config

import (
	"os"
	"path/filepath"
	"time"
)

// Config holds all settings for the Proton Everything Bridge.
type Config struct {
	DataDir string

	// Bind address for all services (default: 127.0.0.1)
	BindHost string

	// Service ports
	IMAPPort    int
	SMTPPort    int
	CardDAVPort int
	CalDAVPort  int
	WebDAVPort  int

	// Service enable/disable
	EnableIMAP    bool
	EnableSMTP    bool
	EnableCardDAV bool
	EnableCalDAV  bool
	EnableWebDAV  bool

	// Hydroxide settings
	HydroxideDebug bool

	// Calendar bridge binary path (child process)
	CalendarBridgeBin string

	// rclone settings (child process)
	RcloneBin    string
	RcloneRemote string

	// Health check interval
	HealthInterval time.Duration

	// Unified auth (Mode 3)
	UnifiedAuth bool
}

// Default returns a Config with sensible defaults.
func Default() Config {
	return Config{
		DataDir:           defaultDataDir(),
		BindHost:          "127.0.0.1",
		IMAPPort:          1143,
		SMTPPort:          1025,
		CardDAVPort:       8080,
		CalDAVPort:        9842,
		WebDAVPort:        9844,
		EnableIMAP:        true,
		EnableSMTP:        true,
		EnableCardDAV:     true,
		EnableCalDAV:      true,
		EnableWebDAV:      true,
		CalendarBridgeBin: "proton-calendar-bridge",
		RcloneBin:         "rclone",
		RcloneRemote:      "proton",
		HealthInterval:    5 * time.Second,
		UnifiedAuth:       false,
	}
}

func defaultDataDir() string {
	if d, err := os.UserConfigDir(); err == nil {
		return filepath.Join(d, "proton-everything-bridge")
	}
	return filepath.Join(os.Getenv("HOME"), ".config", "proton-everything-bridge")
}
