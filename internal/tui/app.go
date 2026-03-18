package tui

import (
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/terraceonhigh/proton-everything-bridge/internal/supervisor"
)

type tickMsg time.Time

// Model is the bubbletea model for the TUI dashboard.
type Model struct {
	supervisor *supervisor.Supervisor
	services   []supervisor.ServiceInfo
	width      int
	height     int
	quitting   bool
}

// NewModel creates a new TUI model.
func NewModel(sup *supervisor.Supervisor) Model {
	return Model{
		supervisor: sup,
		services:   sup.Status(),
		width:      80,
		height:     24,
	}
}

func tickCmd() tea.Cmd {
	return tea.Tick(time.Second, func(t time.Time) tea.Msg {
		return tickMsg(t)
	})
}

func (m Model) Init() tea.Cmd {
	return tickCmd()
}

func (m Model) Update(msg tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := msg.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "ctrl+c":
			m.quitting = true
			return m, tea.Quit
		}
	case tickMsg:
		m.services = m.supervisor.Status()
		return m, tickCmd()
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	}
	return m, nil
}

func (m Model) View() string {
	if m.quitting {
		return ""
	}
	return RenderDashboard(m.services, m.width)
}
