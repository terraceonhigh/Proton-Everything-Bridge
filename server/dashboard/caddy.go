// caddy.go — Caddy Admin API client for dynamic per-user route management.
//
// When a user is provisioned, we POST route entries to Caddy's admin API
// so that /users/{name}/caldav/* routes to their calendar bridge, etc.
// No Caddy restart needed.

package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
)

// CaddyClient manages dynamic routes via Caddy's admin API.
type CaddyClient struct {
	AdminURL string // e.g. "http://caddy:2019"
}

// userRouteID returns a unique route ID for a user, used for cleanup.
func userRouteID(username string) string {
	return "user-" + username
}

// AddUserRoutes adds reverse proxy routes for all of a user's services.
// Routes are tagged with an @id so they can be removed later.
func (c *CaddyClient) AddUserRoutes(username, domain string) error {
	project := projectName(username)
	prefix := "/users/" + username

	// Build route entries for each service
	routes := []caddyRoute{
		{
			ID:      userRouteID(username) + "-caldav",
			Match:   prefix + "/caldav/*",
			Strip:   prefix + "/caldav",
			Upstream: project + "-proton-calendar-bridge-1:9842",
		},
		{
			ID:      userRouteID(username) + "-webdav",
			Match:   prefix + "/webdav/*",
			Strip:   prefix + "/webdav",
			Upstream: project + "-rclone-webdav-1:9844",
		},
		{
			ID:      userRouteID(username) + "-carddav",
			Match:   prefix + "/carddav/*",
			Strip:   prefix + "/carddav",
			Upstream: project + "-hydroxide-1:8080",
		},
	}

	for _, r := range routes {
		if err := c.addRoute(r); err != nil {
			return fmt.Errorf("add route %s: %w", r.ID, err)
		}
	}
	return nil
}

// RemoveUserRoutes removes all Caddy routes for a user.
func (c *CaddyClient) RemoveUserRoutes(username string) error {
	suffixes := []string{"-caldav", "-webdav", "-carddav"}
	for _, s := range suffixes {
		id := userRouteID(username) + s
		if err := c.removeRoute(id); err != nil {
			// Route may not exist (e.g. carddav disabled) — log but continue
			fmt.Printf("remove route %s: %v\n", id, err)
		}
	}
	return nil
}

// caddyRoute represents a single reverse proxy route to add.
type caddyRoute struct {
	ID       string
	Match    string // path matcher, e.g. "/users/alice/caldav/*"
	Strip    string // prefix to strip before proxying
	Upstream string // backend address, e.g. "user-alice-proton-calendar-bridge-1:9842"
}

// addRoute posts a single route to Caddy's admin API.
func (c *CaddyClient) addRoute(r caddyRoute) error {
	// Caddy JSON config route structure
	route := map[string]any{
		"@id": r.ID,
		"match": []map[string]any{
			{"path": []string{r.Match}},
		},
		"handle": []map[string]any{
			{
				"handler": "subroute",
				"routes": []map[string]any{
					{
						"handle": []map[string]any{
							{
								"handler":      "rewrite",
								"strip_path_prefix": r.Strip,
							},
							{
								"handler": "reverse_proxy",
								"upstreams": []map[string]any{
									{"dial": r.Upstream},
								},
							},
						},
					},
				},
			},
		},
	}

	body, err := json.Marshal(route)
	if err != nil {
		return err
	}

	url := c.AdminURL + "/config/apps/http/servers/srv0/routes"
	resp, err := http.Post(url, "application/json", bytes.NewReader(body))
	if err != nil {
		return fmt.Errorf("POST %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("caddy API %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}

// removeRoute deletes a route by its @id.
func (c *CaddyClient) removeRoute(id string) error {
	url := c.AdminURL + "/id/" + id
	req, err := http.NewRequest(http.MethodDelete, url, nil)
	if err != nil {
		return err
	}
	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return fmt.Errorf("DELETE %s: %w", url, err)
	}
	defer resp.Body.Close()

	if resp.StatusCode >= 400 && resp.StatusCode != 404 {
		respBody, _ := io.ReadAll(resp.Body)
		return fmt.Errorf("caddy API %d: %s", resp.StatusCode, string(respBody))
	}
	return nil
}
