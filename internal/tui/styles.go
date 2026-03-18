package tui

import "github.com/charmbracelet/lipgloss"

// Proton dark theme colors
var (
	ColorBg      = lipgloss.Color("#1C1B22")
	ColorFg      = lipgloss.Color("#FFFFFF")
	ColorDim     = lipgloss.Color("#8A8A8A")
	ColorAccent  = lipgloss.Color("#6D4AFF") // Proton purple
	ColorSuccess = lipgloss.Color("#1EA885")
	ColorWarning = lipgloss.Color("#F5A623")
	ColorError   = lipgloss.Color("#DC3545")
)

var (
	// Title bar
	TitleStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorFg).
			Background(ColorAccent).
			Padding(0, 1).
			MarginBottom(1)

	// Service card container
	CardStyle = lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(ColorDim).
			Padding(0, 1).
			MarginBottom(0)

	// Protocol name within a card
	ProtocolStyle = lipgloss.NewStyle().
			Bold(true).
			Foreground(ColorFg)

	// Credential labels
	LabelStyle = lipgloss.NewStyle().
			Foreground(ColorDim)

	// Credential values
	ValueStyle = lipgloss.NewStyle().
			Foreground(ColorFg)

	// Status indicators
	StatusRunning  = lipgloss.NewStyle().Foreground(ColorSuccess).SetString("● Running")
	StatusStarting = lipgloss.NewStyle().Foreground(ColorWarning).SetString("○ Starting")
	StatusError    = lipgloss.NewStyle().Foreground(ColorError).SetString("✗ Error")
	StatusStopped  = lipgloss.NewStyle().Foreground(ColorDim).SetString("- Stopped")

	// Footer help
	HelpStyle = lipgloss.NewStyle().
			Foreground(ColorDim).
			MarginTop(1)
)
