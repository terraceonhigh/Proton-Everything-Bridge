package tui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/terraceonhigh/proton-everything-bridge/internal/supervisor"
)

func statusBadge(status supervisor.ServiceStatus) string {
	switch status {
	case supervisor.StatusRunning:
		return StatusRunning.String()
	case supervisor.StatusStarting:
		return StatusStarting.String()
	case supervisor.StatusError:
		return StatusError.String()
	default:
		return StatusStopped.String()
	}
}

func renderEndpoint(ep supervisor.Endpoint, width int) string {
	var lines []string

	header := fmt.Sprintf("%s", ProtocolStyle.Render(ep.Protocol))
	lines = append(lines, header)

	lines = append(lines, fmt.Sprintf(
		"%s %s   %s %d",
		LabelStyle.Render("Host:"), ValueStyle.Render(ep.Host),
		LabelStyle.Render("Port:"), ep.Port,
	))

	if ep.Path != "" && ep.Path != "/" {
		lines = append(lines, fmt.Sprintf(
			"%s %s",
			LabelStyle.Render("Path:"), ValueStyle.Render(ep.Path),
		))
	}

	if ep.Username != "" {
		lines = append(lines, fmt.Sprintf(
			"%s %s",
			LabelStyle.Render("User:"), ValueStyle.Render(ep.Username),
		))
	}

	if ep.Password != "" {
		lines = append(lines, fmt.Sprintf(
			"%s %s",
			LabelStyle.Render("Pass:"), ValueStyle.Render(ep.Password),
		))
	}

	return strings.Join(lines, "\n")
}

func renderServiceCard(info supervisor.ServiceInfo, width int) string {
	badge := statusBadge(info.Status)

	// Header: service name + status
	nameWidth := width - lipgloss.Width(badge) - 4
	if nameWidth < 10 {
		nameWidth = 10
	}
	name := lipgloss.NewStyle().Bold(true).Foreground(ColorFg).Width(nameWidth).Render(info.Name)
	header := lipgloss.JoinHorizontal(lipgloss.Top, name, badge)

	var sections []string
	sections = append(sections, header)

	if info.Error != "" && info.Status == supervisor.StatusError {
		errMsg := lipgloss.NewStyle().Foreground(ColorError).Render(info.Error)
		sections = append(sections, errMsg)
	}

	for _, ep := range info.Endpoints {
		sections = append(sections, renderEndpoint(ep, width))
	}

	content := strings.Join(sections, "\n")
	return CardStyle.Width(width).Render(content)
}

// RenderDashboard renders the full TUI dashboard.
func RenderDashboard(services []supervisor.ServiceInfo, width int) string {
	var b strings.Builder

	title := TitleStyle.Render(" Proton Everything Bridge ")
	b.WriteString(lipgloss.PlaceHorizontal(width, lipgloss.Center, title))
	b.WriteString("\n")

	cardWidth := width - 2
	if cardWidth > 60 {
		cardWidth = 60
	}
	if cardWidth < 30 {
		cardWidth = 30
	}

	for _, info := range services {
		card := renderServiceCard(info, cardWidth)
		b.WriteString(lipgloss.PlaceHorizontal(width, lipgloss.Center, card))
		b.WriteString("\n")
	}

	help := HelpStyle.Render("q: quit")
	b.WriteString(lipgloss.PlaceHorizontal(width, lipgloss.Center, help))

	return b.String()
}
