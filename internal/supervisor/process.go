package supervisor

import (
	"context"
	"fmt"
	"log"
	"os"
	"os/exec"
	"sync"
	"time"
)

// ProcessService manages a child process (calendar bridge or rclone).
type ProcessService struct {
	name      string
	bin       string
	args      []string
	env       []string
	endpoints []Endpoint
	cmd       *exec.Cmd
	mu        sync.RWMutex
	status    ServiceStatus
	lastErr   string
	cancel    context.CancelFunc
}

// ProcessServiceOpts configures a child process service.
type ProcessServiceOpts struct {
	Name      string
	Bin       string
	Args      []string
	Env       []string
	Endpoints []Endpoint
}

// NewProcessService creates a new child process service.
func NewProcessService(opts ProcessServiceOpts) *ProcessService {
	return &ProcessService{
		name:      opts.Name,
		bin:       opts.Bin,
		args:      opts.Args,
		env:       opts.Env,
		endpoints: opts.Endpoints,
		status:    StatusStopped,
	}
}

func (p *ProcessService) Name() string { return p.name }

func (p *ProcessService) Start(ctx context.Context) error {
	// Check if binary exists
	path, err := exec.LookPath(p.bin)
	if err != nil {
		p.mu.Lock()
		p.status = StatusError
		p.lastErr = fmt.Sprintf("binary not found: %s", p.bin)
		p.mu.Unlock()
		return fmt.Errorf("%s: %w", p.name, err)
	}

	ctx, p.cancel = context.WithCancel(ctx)

	p.cmd = exec.CommandContext(ctx, path, p.args...)
	p.cmd.Env = append(os.Environ(), p.env...)
	p.cmd.Stdout = log.Writer()
	p.cmd.Stderr = log.Writer()

	if err := p.cmd.Start(); err != nil {
		p.mu.Lock()
		p.status = StatusError
		p.lastErr = err.Error()
		p.mu.Unlock()
		return fmt.Errorf("%s: %w", p.name, err)
	}

	p.mu.Lock()
	p.status = StatusStarting
	p.mu.Unlock()

	log.Printf("%s started (PID %d)", p.name, p.cmd.Process.Pid)

	// Wait for the primary endpoint to become available, then monitor process
	go func() {
		if len(p.endpoints) > 0 {
			ep := p.endpoints[0]
			if err := WaitForPort(ctx, ep.Host, ep.Port, 30*time.Second); err != nil {
				p.mu.Lock()
				p.status = StatusError
				p.lastErr = fmt.Sprintf("port %d not ready: %v", ep.Port, err)
				p.mu.Unlock()
				return
			}
		}

		p.mu.Lock()
		p.status = StatusRunning
		p.mu.Unlock()

		if err := p.cmd.Wait(); err != nil {
			p.mu.Lock()
			if p.status != StatusStopping {
				p.status = StatusError
				p.lastErr = err.Error()
			}
			p.mu.Unlock()
		} else {
			p.mu.Lock()
			p.status = StatusStopped
			p.mu.Unlock()
		}
	}()

	return nil
}

func (p *ProcessService) Stop(ctx context.Context) error {
	p.mu.Lock()
	p.status = StatusStopping
	p.mu.Unlock()

	if p.cancel != nil {
		p.cancel()
	}

	p.mu.Lock()
	p.status = StatusStopped
	p.mu.Unlock()
	return nil
}

func (p *ProcessService) Info() ServiceInfo {
	p.mu.RLock()
	defer p.mu.RUnlock()
	return ServiceInfo{
		Name:      p.name,
		Status:    p.status,
		Error:     p.lastErr,
		Endpoints: p.endpoints,
	}
}

func (p *ProcessService) Healthy(ctx context.Context) error {
	p.mu.RLock()
	status := p.status
	p.mu.RUnlock()

	if status != StatusRunning {
		return fmt.Errorf("not running (status: %s)", status)
	}

	if len(p.endpoints) > 0 {
		ep := p.endpoints[0]
		if err := ProbeTCP(ctx, ep.Host, ep.Port); err != nil {
			p.mu.Lock()
			p.status = StatusError
			p.lastErr = fmt.Sprintf("health check failed: %v", err)
			p.mu.Unlock()
			return err
		}
	}
	return nil
}
