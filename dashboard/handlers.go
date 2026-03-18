// handlers.go — HTTP handlers for the bridge-style dashboard.
//
// Pages:
//   GET  /                          — Account list with service health
//   POST /accounts                  — Add a new account
//   GET  /accounts/{name}/setup     — Per-account endpoint URLs
//   GET  /accounts/{name}/bridge    — Per-account CLI auth commands
//   POST /accounts/{name}/remove    — Remove an account

package main

import (
	"html/template"
	"log"
	"net/http"
	"regexp"
	"strings"
)

// Handlers holds dependencies for all HTTP handlers.
type Handlers struct {
	Docker *DockerCompose
	Caddy  *CaddyClient
	Domain string
	Tmpl   *template.Template
}

// AccountData represents a user account and its service health for templates.
type AccountData struct {
	Name     string
	Services []ServiceStatus
}

// validName checks that a username is safe for use in Docker project names.
var validName = regexp.MustCompile(`^[a-z][a-z0-9_-]{0,31}$`)

// Index renders the main dashboard — account list with service health.
func (h *Handlers) Index(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	users, err := h.Docker.ListUsers()
	if err != nil {
		log.Printf("list users: %v", err)
		users = nil
	}

	var accounts []AccountData
	for _, name := range users {
		svcs, err := h.Docker.GetServiceHealth(name)
		if err != nil {
			log.Printf("health %s: %v", name, err)
		}
		accounts = append(accounts, AccountData{Name: name, Services: svcs})
	}

	data := map[string]any{
		"Domain":   h.Domain,
		"Accounts": accounts,
	}
	if err := h.Tmpl.ExecuteTemplate(w, "accounts.html", data); err != nil {
		log.Printf("template: %v", err)
	}
}

// Accounts handles POST /accounts — create a new user stack.
func (h *Handlers) Accounts(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	name := strings.TrimSpace(r.FormValue("name"))
	if !validName.MatchString(name) {
		http.Error(w, "Invalid name. Use lowercase letters, numbers, hyphens (2-32 chars).", http.StatusBadRequest)
		return
	}

	log.Printf("creating account: %s", name)

	// Start the user's bridge containers
	if err := h.Docker.CreateUserStack(name); err != nil {
		log.Printf("create stack %s: %v", name, err)
		http.Error(w, "Failed to create containers: "+err.Error(), http.StatusInternalServerError)
		return
	}

	// Add Caddy routes for this user
	if err := h.Caddy.AddUserRoutes(name, h.Domain); err != nil {
		log.Printf("add routes %s: %v", name, err)
		// Containers are running but routes failed — not fatal, will reconcile
	}

	redirectURL := "/accounts/" + name + "/bridge"
	log.Printf("account %s created, redirecting to %s", name, redirectURL)
	http.Redirect(w, r, redirectURL, http.StatusSeeOther)
}

// AccountAction routes /accounts/{name}/{action} requests.
func (h *Handlers) AccountAction(w http.ResponseWriter, r *http.Request) {
	// Parse /accounts/{name}/{action}
	parts := strings.Split(strings.TrimPrefix(r.URL.Path, "/accounts/"), "/")
	if len(parts) < 1 || parts[0] == "" {
		http.NotFound(w, r)
		return
	}

	name := parts[0]
	action := ""
	if len(parts) > 1 {
		action = parts[1]
	}

	switch action {
	case "setup":
		h.Setup(w, r, name)
	case "bridge":
		h.BridgeLogin(w, r, name)
	case "remove":
		h.Remove(w, r, name)
	default:
		http.NotFound(w, r)
	}
}

// Setup renders the per-account endpoint URLs page.
func (h *Handlers) Setup(w http.ResponseWriter, r *http.Request, name string) {
	data := map[string]any{
		"Domain": h.Domain,
		"Name":   name,
	}
	if err := h.Tmpl.ExecuteTemplate(w, "setup.html", data); err != nil {
		log.Printf("template: %v", err)
	}
}

// BridgeLogin renders the per-account CLI auth commands page.
func (h *Handlers) BridgeLogin(w http.ResponseWriter, r *http.Request, name string) {
	data := map[string]any{
		"Name": name,
	}
	if err := h.Tmpl.ExecuteTemplate(w, "bridge-login.html", data); err != nil {
		log.Printf("template: %v", err)
	}
}

// Remove handles POST /accounts/{name}/remove — tear down a user stack.
func (h *Handlers) Remove(w http.ResponseWriter, r *http.Request, name string) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	log.Printf("removing account: %s", name)

	// Remove Caddy routes first
	if err := h.Caddy.RemoveUserRoutes(name); err != nil {
		log.Printf("remove routes %s: %v", name, err)
	}

	// Stop and remove containers + volumes
	if err := h.Docker.RemoveUserStack(name); err != nil {
		log.Printf("remove stack %s: %v", name, err)
		http.Error(w, "Failed to remove containers: "+err.Error(), http.StatusInternalServerError)
		return
	}

	log.Printf("account %s removed", name)
	http.Redirect(w, r, "/", http.StatusSeeOther)
}
