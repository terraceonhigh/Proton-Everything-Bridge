// templates.go — Loads embedded HTML templates.

package main

import (
	"embed"
	"html/template"
)

//go:embed templates/*.html
var templateFS embed.FS

func loadTemplates() *template.Template {
	funcMap := template.FuncMap{
		"serviceLabel": serviceLabel,
		"serviceOK":    serviceOK,
	}
	return template.Must(
		template.New("").Funcs(funcMap).ParseFS(templateFS, "templates/*.html"),
	)
}

// serviceLabel returns a human-friendly label for a Docker service name.
func serviceLabel(name string) string {
	switch name {
	case "proton-bridge":
		return "Proton Bridge"
	default:
		return name
	}
}

// serviceOK returns true if a service is running and healthy (or has no healthcheck).
func serviceOK(s ServiceStatus) bool {
	return s.Running && (s.Health == "healthy" || s.Health == "")
}
