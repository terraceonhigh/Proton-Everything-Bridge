package supervisor

import "context"

// ServiceStatus represents the current state of a service.
type ServiceStatus int

const (
	StatusStopped  ServiceStatus = iota
	StatusStarting               // launched but not yet healthy
	StatusRunning                // healthy and accepting connections
	StatusError                  // crashed or failed health check
	StatusStopping               // shutting down
)

func (s ServiceStatus) String() string {
	switch s {
	case StatusStopped:
		return "Stopped"
	case StatusStarting:
		return "Starting"
	case StatusRunning:
		return "Running"
	case StatusError:
		return "Error"
	case StatusStopping:
		return "Stopping"
	default:
		return "Unknown"
	}
}

// Endpoint describes a single protocol endpoint exposed by a service.
type Endpoint struct {
	Protocol string // "IMAP", "SMTP", "CardDAV", "CalDAV", "WebDAV"
	Host     string
	Port     int
	Path     string // URL path for HTTP-based protocols (e.g. "/caldav/")
	Username string // bridge username (if known)
	Password string // bridge password (if known)
}

// ServiceInfo is a snapshot of a service's current state.
type ServiceInfo struct {
	Name      string
	Status    ServiceStatus
	Error     string // last error message, empty if healthy
	Endpoints []Endpoint
}

// Service is the interface implemented by all managed services.
type Service interface {
	Name() string
	Start(ctx context.Context) error
	Stop(ctx context.Context) error
	Info() ServiceInfo
	Healthy(ctx context.Context) error
}
