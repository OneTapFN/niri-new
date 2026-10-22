import QtQuick
import Quickshell
import Quickshell.Wayland

// Custom context menu for system tray items.
//
// QsMenuAnchor cannot be used here because its platform menu needs
// QApplication mode and a real xdg_popup parent, neither of which we have.
// This renders the DBus menu tree directly inside an overlay layer surface.
// Submenus replace the current list and a "Back" row returns to the parent,
// which avoids recursive QML components.
PanelWindow {
	id: trayMenu

	property var menuHandle: null
	property real anchorX: 0
	property real anchorY: Theme.barHeight

	// Current submenu depth, 0 = root menu.
	property int level: 0

	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-traymenu"

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	// One opener per depth, reused when navigating.
	QsMenuOpener { id: opener0 }
	QsMenuOpener { id: opener1 }
	QsMenuOpener { id: opener2 }
	QsMenuOpener { id: opener3 }
	QsMenuOpener { id: opener4 }
	QsMenuOpener { id: opener5 }

	readonly property var openers: [opener0, opener1, opener2, opener3, opener4, opener5]
	readonly property var currentCollection: openers[level].children
	readonly property string currentTitle: level > 0 && openers[level].menu
		? openers[level].menu.text
		: ""

	readonly property int menuWidth: 250
	readonly property real menuHeight: Math.min(listContent.implicitHeight + 8, 420)

	function openFor(handle, x, y) {
		if (!handle)
			return;
		clearStack();
		menuHandle = handle;
		anchorX = x;
		anchorY = y;
		level = 0;
		openers[0].menu = handle;
		visible = true;
	}

	function clearStack() {
		for (let i = 0; i < openers.length; i++)
			openers[i].menu = null;
	}

	function close() {
		visible = false;
	}

	function navigate(entry) {
		if (!entry || !entry.enabled)
			return;
		if (entry.hasChildren) {
			if (level + 1 < openers.length) {
				openers[level + 1].menu = entry;
				level++;
			}
			return;
		}
		entry.triggered();
		close();
	}

	function back() {
		if (level === 0) {
			close();
			return;
		}
		openers[level].menu = null;
		level--;
	}

	onVisibleChanged: {
		if (!visible)
			clearStack();
	}

	// Click outside the bubble closes the menu.
	MouseArea {
		anchors.fill: parent
		onClicked: trayMenu.close()
	}

	Shortcut {
		sequence: "Escape"
		onActivated: trayMenu.close()
	}

	Rectangle {
		id: bubble
		width: trayMenu.menuWidth
		height: trayMenu.menuHeight
		x: Math.max(4, Math.min(trayMenu.anchorX - width / 2, parent.width - width - 4))
		y: Math.min(trayMenu.anchorY + 4, parent.height - height - 4)
		radius: 8
		color: Theme.popupBg
		border.width: 1
		border.color: Theme.border

		// Swallow clicks on the menu background.
		MouseArea {
			anchors.fill: parent
		}

		Flickable {
			id: flick
			anchors.fill: parent
			anchors.margins: 4
			contentWidth: width
			contentHeight: listContent.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: listContent
				width: flick.width
				spacing: 1

				// Back row for submenus
				Item {
					visible: trayMenu.level > 0
					width: parent.width
					height: visible ? 28 : 0

					Rectangle {
						anchors.fill: parent
						radius: 5
						color: backArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
					}

					Row {
						anchors.left: parent.left
						anchors.leftMargin: 8
						anchors.verticalCenter: parent.verticalCenter
						spacing: 8

						Text {
							text: "\uf053"
							color: Theme.textDim
							font.family: Theme.iconFamily
							font.pixelSize: 9
						}

						Text {
							text: trayMenu.currentTitle !== "" ? trayMenu.currentTitle.replace(/&/g, "") : "Back"
							color: Theme.text
							font.family: Theme.fontFamily
							font.pixelSize: 12
							font.weight: Font.DemiBold
						}
					}

					MouseArea {
						id: backArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: trayMenu.back()
					}
				}

				Rectangle {
					visible: trayMenu.level > 0
					width: parent.width
					height: 1
					color: Qt.rgba(1, 1, 1, 0.10)
				}

				Repeater {
					model: trayMenu.currentCollection ? trayMenu.currentCollection.values : []

					delegate: TrayMenuItem {
						required property var modelData
						width: listContent.width
						entry: modelData
						onActivated: entry => trayMenu.navigate(entry)
					}
				}
			}
		}
	}
}
