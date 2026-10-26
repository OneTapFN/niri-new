import QtQuick
import Quickshell
import Quickshell.Io

//@ pragma IconTheme breeze-dark

ShellRoot {
	Bar {
		id: bar
		quickMenu: menu
		mediaMenu: media
		trayMenu: tray
		weatherMenu: weatherMenu
		calendarMenu: calendarMenu
	}

	QuickMenu {
		id: menu
	}

	WeatherMenu {
		id: weatherMenu
	}

	CalendarMenu {
		id: calendarMenu
	}

	MediaMenu {
		id: media
	}

	TrayMenu {
		id: tray
	}
}
