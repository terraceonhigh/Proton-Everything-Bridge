package supervisor

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"time"
)

// ProbeTCP tries to connect to host:port. Returns nil if successful.
func ProbeTCP(ctx context.Context, host string, port int) error {
	addr := fmt.Sprintf("%s:%d", host, port)
	d := net.Dialer{Timeout: 2 * time.Second}
	conn, err := d.DialContext(ctx, "tcp", addr)
	if err != nil {
		return err
	}
	conn.Close()
	return nil
}

// ProbeHTTP sends a GET to the given URL. Returns nil if the service
// responds with 2xx or 401 (auth required = alive).
func ProbeHTTP(ctx context.Context, url string) error {
	req, err := http.NewRequestWithContext(ctx, "GET", url, nil)
	if err != nil {
		return err
	}
	client := &http.Client{Timeout: 2 * time.Second}
	resp, err := client.Do(req)
	if err != nil {
		return err
	}
	resp.Body.Close()
	if resp.StatusCode == http.StatusUnauthorized ||
		(resp.StatusCode >= 200 && resp.StatusCode < 400) {
		return nil
	}
	return fmt.Errorf("unhealthy: status %d", resp.StatusCode)
}

// WaitForPort polls a TCP port until it becomes available or the timeout expires.
func WaitForPort(ctx context.Context, host string, port int, timeout time.Duration) error {
	deadline := time.After(timeout)
	ticker := time.NewTicker(500 * time.Millisecond)
	defer ticker.Stop()
	for {
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-deadline:
			return fmt.Errorf("timeout waiting for %s:%d", host, port)
		case <-ticker.C:
			if ProbeTCP(ctx, host, port) == nil {
				return nil
			}
		}
	}
}
