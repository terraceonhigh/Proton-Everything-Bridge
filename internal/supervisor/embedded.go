package supervisor

import (
	"context"
	"fmt"
	"io"
	"log"
	"net/http"
	"sync"

	imapserver "github.com/emersion/go-imap/server"
	gosmtp "github.com/emersion/go-smtp"

	"github.com/emersion/hydroxide/auth"
	"github.com/emersion/hydroxide/carddav"
	"github.com/emersion/hydroxide/events"
	imapbackend "github.com/emersion/hydroxide/imap"
	"github.com/emersion/hydroxide/protonmail"
	smtpbackend "github.com/emersion/hydroxide/smtp"

	"github.com/terraceonhigh/proton-everything-bridge/internal/config"
)

// HydroxideService runs hydroxide's IMAP, SMTP, and CardDAV servers in-process.
type HydroxideService struct {
	cfg           config.Config
	authManager   *auth.Manager
	eventsManager *events.Manager
	cancel        context.CancelFunc
	mu            sync.RWMutex
	status        ServiceStatus
	lastErr       string
}

// NewHydroxideService creates a new embedded hydroxide service.
func NewHydroxideService(cfg config.Config) *HydroxideService {
	newClient := func() *protonmail.Client {
		return &protonmail.Client{
			RootURL:    "https://mail.proton.me/api",
			AppVersion: "Other",
			Debug:      cfg.HydroxideDebug,
		}
	}
	return &HydroxideService{
		cfg:           cfg,
		authManager:   auth.NewManager(newClient),
		eventsManager: events.NewManager(),
		status:        StatusStopped,
	}
}

func (h *HydroxideService) Name() string { return "Hydroxide" }

func (h *HydroxideService) Start(ctx context.Context) error {
	h.mu.Lock()
	h.status = StatusStarting
	h.lastErr = ""
	h.mu.Unlock()

	ctx, h.cancel = context.WithCancel(ctx)
	errCh := make(chan error, 3)

	if h.cfg.EnableSMTP {
		go func() {
			addr := fmt.Sprintf("%s:%d", h.cfg.BindHost, h.cfg.SMTPPort)
			errCh <- h.serveSMTP(addr)
		}()
	}

	if h.cfg.EnableIMAP {
		go func() {
			addr := fmt.Sprintf("%s:%d", h.cfg.BindHost, h.cfg.IMAPPort)
			errCh <- h.serveIMAP(addr)
		}()
	}

	if h.cfg.EnableCardDAV {
		go func() {
			addr := fmt.Sprintf("%s:%d", h.cfg.BindHost, h.cfg.CardDAVPort)
			errCh <- h.serveCardDAV(ctx, addr)
		}()
	}

	// Monitor for first fatal error
	go func() {
		select {
		case err := <-errCh:
			h.mu.Lock()
			h.status = StatusError
			h.lastErr = err.Error()
			h.mu.Unlock()
		case <-ctx.Done():
		}
	}()

	h.mu.Lock()
	h.status = StatusRunning
	h.mu.Unlock()

	return nil
}

func (h *HydroxideService) Stop(ctx context.Context) error {
	h.mu.Lock()
	h.status = StatusStopping
	h.mu.Unlock()

	if h.cancel != nil {
		h.cancel()
	}

	h.mu.Lock()
	h.status = StatusStopped
	h.mu.Unlock()
	return nil
}

func (h *HydroxideService) Info() ServiceInfo {
	h.mu.RLock()
	defer h.mu.RUnlock()

	var endpoints []Endpoint

	if h.cfg.EnableIMAP {
		endpoints = append(endpoints, Endpoint{
			Protocol: "IMAP",
			Host:     h.cfg.BindHost,
			Port:     h.cfg.IMAPPort,
		})
	}
	if h.cfg.EnableSMTP {
		endpoints = append(endpoints, Endpoint{
			Protocol: "SMTP",
			Host:     h.cfg.BindHost,
			Port:     h.cfg.SMTPPort,
		})
	}
	if h.cfg.EnableCardDAV {
		endpoints = append(endpoints, Endpoint{
			Protocol: "CardDAV",
			Host:     h.cfg.BindHost,
			Port:     h.cfg.CardDAVPort,
			Path:     "/",
		})
	}

	return ServiceInfo{
		Name:      h.Name(),
		Status:    h.status,
		Error:     h.lastErr,
		Endpoints: endpoints,
	}
}

func (h *HydroxideService) Healthy(ctx context.Context) error {
	h.mu.RLock()
	status := h.status
	h.mu.RUnlock()

	if status != StatusRunning {
		return fmt.Errorf("not running (status: %s)", status)
	}

	// Probe each enabled endpoint
	if h.cfg.EnableIMAP {
		if err := ProbeTCP(ctx, h.cfg.BindHost, h.cfg.IMAPPort); err != nil {
			h.mu.Lock()
			h.status = StatusError
			h.lastErr = fmt.Sprintf("IMAP probe failed: %v", err)
			h.mu.Unlock()
			return err
		}
	}
	return nil
}

func (h *HydroxideService) serveSMTP(addr string) error {
	be := smtpbackend.New(h.authManager)
	s := gosmtp.NewServer(be)
	s.Addr = addr
	s.Domain = "localhost"
	s.AllowInsecureAuth = true
	log.Printf("SMTP server listening on %s", addr)
	return s.ListenAndServe()
}

func (h *HydroxideService) serveIMAP(addr string) error {
	be := imapbackend.New(h.authManager, h.eventsManager)
	s := imapserver.New(be)
	s.Addr = addr
	s.AllowInsecureAuth = true
	log.Printf("IMAP server listening on %s", addr)
	return s.ListenAndServe()
}

func (h *HydroxideService) serveCardDAV(ctx context.Context, addr string) error {
	handlers := make(map[string]http.Handler)

	s := &http.Server{
		Addr: addr,
		Handler: http.HandlerFunc(func(resp http.ResponseWriter, req *http.Request) {
			resp.Header().Set("WWW-Authenticate", "Basic")

			username, password, ok := req.BasicAuth()
			if !ok {
				resp.WriteHeader(http.StatusUnauthorized)
				io.WriteString(resp, "Credentials are required")
				return
			}

			c, privateKeys, err := h.authManager.Auth(username, password)
			if err != nil {
				if err == auth.ErrUnauthorized {
					resp.WriteHeader(http.StatusUnauthorized)
				} else {
					resp.WriteHeader(http.StatusInternalServerError)
				}
				io.WriteString(resp, err.Error())
				return
			}

			handler, ok := handlers[username]
			if !ok {
				ch := make(chan *protonmail.Event)
				h.eventsManager.Register(c, username, ch, nil)
				handler = carddav.NewHandler(c, privateKeys, ch)
				handlers[username] = handler
			}

			handler.ServeHTTP(resp, req)
		}),
	}

	log.Printf("CardDAV server listening on %s", addr)

	go func() {
		<-ctx.Done()
		s.Close()
	}()

	return s.ListenAndServe()
}
