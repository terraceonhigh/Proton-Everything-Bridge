package supervisor

import (
	"context"
	"fmt"
	"log"
	"time"

	"github.com/terraceonhigh/proton-everything-bridge/internal/config"
)

// Supervisor manages the lifecycle of all bridge services.
type Supervisor struct {
	services []Service
	cfg      config.Config
}

// New creates a Supervisor with services configured from cfg.
func New(cfg config.Config) *Supervisor {
	var services []Service

	// Hydroxide (embedded, in-process) — IMAP, SMTP, CardDAV
	if cfg.EnableIMAP || cfg.EnableSMTP || cfg.EnableCardDAV {
		services = append(services, NewHydroxideService(cfg))
	}

	// Calendar bridge (child process)
	if cfg.EnableCalDAV {
		services = append(services, NewProcessService(ProcessServiceOpts{
			Name: "Calendar Bridge",
			Bin:  cfg.CalendarBridgeBin,
			Env: []string{
				"PCB_PROVIDER=proton",
				fmt.Sprintf("PCB_BIND_ADDRESS=%s:%d", cfg.BindHost, cfg.CalDAVPort),
				"PCB_REQUIRE_TOKEN=false",
			},
			Endpoints: []Endpoint{{
				Protocol: "CalDAV",
				Host:     cfg.BindHost,
				Port:     cfg.CalDAVPort,
				Path:     "/caldav/",
			}},
		}))
	}

	// rclone WebDAV (child process)
	if cfg.EnableWebDAV {
		services = append(services, NewProcessService(ProcessServiceOpts{
			Name: "rclone WebDAV",
			Bin:  cfg.RcloneBin,
			Args: []string{
				"serve", "webdav",
				cfg.RcloneRemote + ":",
				"--addr", fmt.Sprintf("%s:%d", cfg.BindHost, cfg.WebDAVPort),
				"--vfs-cache-mode", "full",
			},
			Endpoints: []Endpoint{{
				Protocol: "WebDAV",
				Host:     cfg.BindHost,
				Port:     cfg.WebDAVPort,
				Path:     "/",
			}},
		}))
	}

	return &Supervisor{services: services, cfg: cfg}
}

// StartAll launches all services. Errors are logged but do not stop other services.
func (s *Supervisor) StartAll(ctx context.Context) {
	for _, svc := range s.services {
		if err := svc.Start(ctx); err != nil {
			log.Printf("failed to start %s: %v", svc.Name(), err)
		}
	}
}

// StopAll gracefully shuts down all services in reverse order.
func (s *Supervisor) StopAll(ctx context.Context) {
	for i := len(s.services) - 1; i >= 0; i-- {
		if err := s.services[i].Stop(ctx); err != nil {
			log.Printf("failed to stop %s: %v", s.services[i].Name(), err)
		}
	}
}

// Status returns a snapshot of all service states.
func (s *Supervisor) Status() []ServiceInfo {
	infos := make([]ServiceInfo, len(s.services))
	for i, svc := range s.services {
		infos[i] = svc.Info()
	}
	return infos
}

// HealthLoop runs periodic health checks on all services.
func (s *Supervisor) HealthLoop(ctx context.Context) {
	ticker := time.NewTicker(s.cfg.HealthInterval)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return
		case <-ticker.C:
			for _, svc := range s.services {
				svc.Healthy(ctx)
			}
		}
	}
}
