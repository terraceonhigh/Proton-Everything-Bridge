// Proton DAV Server — Dashboard
//
// Bridge-style web panel for managing per-user Proton bridge stacks.
// On startup, reconciles Caddy routes for all existing user stacks.

package main

import (
	"log"
	"net/http"
	"os"
	"time"
)

func main() {
	domain := envOr("DOMAIN", "localhost")
	caddyAdmin := envOr("CADDY_ADMIN", "http://caddy:2019")
	composePath := envOr("COMPOSE_FILE", "/app/docker-compose.user.yml")
	listenAddr := envOr("LISTEN_ADDR", ":8080")

	dc := &DockerCompose{ComposePath: composePath}
	caddy := &CaddyClient{AdminURL: caddyAdmin}

	// Reconcile Caddy routes on startup (handles restarts)
	go func() {
		// Give Caddy a moment to start accepting admin API requests
		time.Sleep(3 * time.Second)
		if err := reconcileRoutes(dc, caddy, domain); err != nil {
			log.Printf("route reconciliation: %v", err)
		}
	}()

	h := &Handlers{
		Docker:   dc,
		Caddy:    caddy,
		Domain:   domain,
		Tmpl:     loadTemplates(),
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/", h.Index)
	mux.HandleFunc("/accounts", h.Accounts)
	mux.HandleFunc("/accounts/", h.AccountAction)

	log.Printf("dashboard listening on %s (domain: %s)", listenAddr, domain)
	if err := http.ListenAndServe(listenAddr, mux); err != nil {
		log.Fatal(err)
	}
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

// reconcileRoutes re-adds Caddy routes for all existing user stacks.
// Called on startup to survive Caddy restarts.
func reconcileRoutes(dc *DockerCompose, caddy *CaddyClient, domain string) error {
	users, err := dc.ListUsers()
	if err != nil {
		return err
	}
	log.Printf("reconciling routes for %d user(s)", len(users))
	for _, name := range users {
		if err := caddy.AddUserRoutes(name, domain); err != nil {
			log.Printf("  %s: route add failed: %v", name, err)
		} else {
			log.Printf("  %s: routes OK", name)
		}
	}
	return nil
}
