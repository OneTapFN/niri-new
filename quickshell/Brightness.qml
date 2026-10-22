pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Backlight state shared by the bar and the quick menu.
Singleton {
	id: brightness

	property int percent: 50
	property bool available: false

	// Debounce writes so dragging the slider doesn't spawn a process per pixel.
	property int pendingPercent: -1
	property real value: percent / 100

	function refresh() {
		if (!getProc.running)
			getProc.running = true;
	}

	function setPercent(p) {
		const clamped = Math.max(1, Math.min(100, Math.round(p)));
		percent = clamped;
		pendingPercent = clamped;
		applyTimer.restart();
	}

	Timer {
		id: applyTimer
		interval: 80
		repeat: false
		onTriggered: {
			if (brightness.pendingPercent >= 0) {
				Quickshell.execDetached([
					"brightnessctl",
					"--class=backlight",
					"set",
					brightness.pendingPercent + "%"
				]);
			}
		}
	}

	Process {
		id: getProc

		command: ["brightnessctl", "-m", "--class=backlight", "info"]
		running: true

		stdout: SplitParser {
			onRead: line => {
				const parts = line.split(",");
				if (parts.length >= 4) {
					const parsed = parseInt(parts[3]);
					if (!isNaN(parsed)) {
						brightness.percent = parsed;
						brightness.available = true;
					}
				}
			}
		}
	}

	Timer {
		interval: 15000
		running: true
		repeat: true
		onTriggered: brightness.refresh()
	}
}