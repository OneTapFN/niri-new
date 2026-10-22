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
	}

	QuickMenu {
		id: menu
	}

	MediaMenu {
		id: media
	}

	TrayMenu {
		id: tray
	}
}
