pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Live mirror of the niri compositor state, streamed over its IPC socket.
// Used for the workspace indicator, the focused window title and the
// keyboard layout badge.
Singleton {
	id: niri

	// [{ id, idx, name, output, is_active, is_focused, is_urgent, active_window_id }]
	property var workspaces: []
	// [{ id, title, app_id, workspace_id, is_focused }]
	property var windows: []
	property var layoutNames: []
	property int layoutIdx: 0
	property int focusedWindowId: -1

	readonly property var sortedWorkspaces: workspaces.slice().sort((a, b) => a.idx - b.idx)

	readonly property string focusedTitle: {
		const w = windows.find(w => w.id === focusedWindowId);
		return w ? w.title : "";
	}

	readonly property string layoutCode: {
		if (layoutIdx < 0 || layoutIdx >= layoutNames.length)
			return "??";
		const name = layoutNames[layoutIdx] || "";
		const lower = name.toLowerCase();
		if (lower.startsWith("english")) return "US";
		if (lower.startsWith("russian")) return "RU";
		return name.slice(0, 2).toUpperCase();
	}

	function updateWorkspace(id, patch) {
		workspaces = workspaces.map(w => w.id === id ? Object.assign({}, w, patch) : w);
	}

	function handleEvent(line) {
		let evt;
		try {
			evt = JSON.parse(line);
		} catch (e) {
			return;
		}

		if (evt.WorkspacesChanged) {
			workspaces = evt.WorkspacesChanged.workspaces;
		} else if (evt.WorkspaceActivated) {
			const id = evt.WorkspaceActivated.id;
			const focused = evt.WorkspaceActivated.focused;
			workspaces = workspaces.map(w => Object.assign({}, w, {
				is_active: w.id === id,
				is_focused: w.id === id ? focused : false
			}));
		} else if (evt.WorkspaceUrgencyChanged) {
			updateWorkspace(evt.WorkspaceUrgencyChanged.id, { is_urgent: evt.WorkspaceUrgencyChanged.urgent });
		} else if (evt.WorkspacesReordered) {
			// niri sends the full new list as a delta of ids, re-request on focus events.
		} else if (evt.WindowsChanged) {
			windows = evt.WindowsChanged.windows;
			syncFocus();
		} else if (evt.WindowOpenedOrChanged) {
			const win = evt.WindowOpenedOrChanged.window;
			const idx = windows.findIndex(w => w.id === win.id);
			if (idx === -1)
				windows = windows.concat([win]);
			else
				windows = windows.map(w => w.id === win.id ? win : w);
		} else if (evt.WindowClosed) {
			const id = evt.WindowClosed.id;
			windows = windows.filter(w => w.id !== id);
		} else if (evt.WindowFocusChanged) {
			const id = evt.WindowFocusChanged.id;
			focusedWindowId = (id === undefined || id === null) ? -1 : id;
		} else if (evt.KeyboardLayoutsChanged) {
			const layouts = evt.KeyboardLayoutsChanged.keyboard_layouts;
			if (layouts) {
				layoutNames = layouts.names;
				layoutIdx = layouts.current_idx;
			}
		} else if (evt.KeyboardLayoutSwitched) {
			layoutIdx = evt.KeyboardLayoutSwitched.idx;
		}
	}

	function syncFocus() {
		const w = windows.find(w => w.is_focused);
		if (w)
			focusedWindowId = w.id;
	}

	Socket {
		id: socket

		path: Quickshell.env("NIRI_SOCKET")
		connected: true

		onConnectionStateChanged: {
			if (socket.connected) {
				// niri expects every request to be a JSON encoded string.
				socket.write("\"EventStream\"\n");
				socket.flush();
			}
		}

		parser: SplitParser {
			onRead: line => niri.handleEvent(line)
		}
	}
}