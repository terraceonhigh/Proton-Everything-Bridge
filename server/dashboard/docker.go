// docker.go — Wraps docker compose CLI for per-user stack management.
//
// Each user gets an isolated Compose project via:
//   docker compose -p user-{name} -f docker-compose.user.yml up -d

package main

import (
	"encoding/json"
	"fmt"
	"os/exec"
	"strings"
)

// DockerCompose manages per-user bridge stacks via the docker compose CLI.
type DockerCompose struct {
	ComposePath string // Path to docker-compose.user.yml
}

// projectName returns the Compose project name for a user.
func projectName(username string) string {
	return "user-" + username
}

// CreateUserStack starts all bridge containers for a user.
func (dc *DockerCompose) CreateUserStack(name string) error {
	return dc.compose(name, "up", "-d", "--build")
}

// RemoveUserStack stops and removes all containers and volumes for a user.
func (dc *DockerCompose) RemoveUserStack(name string) error {
	return dc.compose(name, "down", "-v")
}

// ListUsers returns the names of all provisioned users by scanning Docker
// Compose projects that match the "user-*" naming convention.
func (dc *DockerCompose) ListUsers() ([]string, error) {
	cmd := exec.Command("docker", "compose", "ls", "--format", "json")
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("docker compose ls: %w", err)
	}

	var projects []struct {
		Name   string `json:"Name"`
		Status string `json:"Status"`
	}
	if err := json.Unmarshal(out, &projects); err != nil {
		return nil, fmt.Errorf("parse compose ls: %w", err)
	}

	var users []string
	for _, p := range projects {
		if strings.HasPrefix(p.Name, "user-") {
			users = append(users, strings.TrimPrefix(p.Name, "user-"))
		}
	}
	return users, nil
}

// ServiceStatus represents the health of a single bridge service.
type ServiceStatus struct {
	Name    string // e.g. "proton-mail-bridge"
	Running bool
	Health  string // "healthy", "unhealthy", "starting", ""
}

// GetServiceHealth returns the status of all services in a user's stack.
func (dc *DockerCompose) GetServiceHealth(name string) ([]ServiceStatus, error) {
	cmd := exec.Command(
		"docker", "compose",
		"-p", projectName(name),
		"-f", dc.ComposePath,
		"ps", "--format", "json",
	)
	out, err := cmd.Output()
	if err != nil {
		return nil, fmt.Errorf("docker compose ps: %w", err)
	}

	// docker compose ps --format json outputs one JSON object per line
	var statuses []ServiceStatus
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if line == "" {
			continue
		}
		var svc struct {
			Service string `json:"Service"`
			State   string `json:"State"`
			Health  string `json:"Health"`
		}
		if err := json.Unmarshal([]byte(line), &svc); err != nil {
			continue
		}
		statuses = append(statuses, ServiceStatus{
			Name:    svc.Service,
			Running: svc.State == "running",
			Health:  svc.Health,
		})
	}
	return statuses, nil
}

// compose runs a docker compose command for a specific user project.
func (dc *DockerCompose) compose(username string, args ...string) error {
	cmdArgs := []string{
		"compose",
		"-p", projectName(username),
		"-f", dc.ComposePath,
	}
	cmdArgs = append(cmdArgs, args...)

	cmd := exec.Command("docker", cmdArgs...)
	cmd.Stdout = nil
	cmd.Stderr = nil
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("docker compose -p %s %s: %w", projectName(username), strings.Join(args, " "), err)
	}
	return nil
}
