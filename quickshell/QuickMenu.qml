import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Networking

// GNOME style quick settings dropdown: Wi-Fi, Bluetooth, sound, brightness
// and session actions.
//
// Implemented as a fullscreen overlay layer surface rather than a PopupWindow:
// Qt 6.8 cannot create an xdg_popup from a layer-shell parent, which makes
// PopupWindow turn into a regular tiled toplevel.
PanelWindow {
	id: menu

	// Wi-Fi password entry state.
	property var pskNetwork: null
	property string pskText: ""

	// Collapsible device lists.
	property bool showOutputs: false
	property bool showInputs: false

	// Two step confirmation for session actions.
	property string pendingSession: ""

	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-menu"

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	readonly property real panelTop: Theme.barHeight + 4
	readonly property real maxPanelHeight: Math.max(300, height - panelTop - 8)

	// --- services -------------------------------------------------------
	// Pipewire objects are unbound until referenced by a tracker.
	PwObjectTracker {
		objects: [menu.sink, menu.source]
	}

	PwObjectTracker {
		objects: menu.sinks
	}

	PwObjectTracker {
		objects: menu.sources
	}

	readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
	readonly property var wifiNetworks: {
		if (!wifiDevice)
			return [];
		const list = wifiDevice.networks.values.slice();
		list.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || b.signalStrength - a.signalStrength);
		return list.slice(0, 6);
	}
	readonly property var connectedWifi: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null

	readonly property var btAdapter: Bluetooth.defaultAdapter
	readonly property var btDevices: {
		if (!btAdapter)
			return [];
		const mac = /^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i;
		const list = btAdapter.devices.values.filter(d =>
			d.connected || d.paired || (d.name && d.name.length > 0 && !mac.test(d.name)));
		list.sort((a, b) => (b.connected ? 1 : 0) - (a.connected ? 1 : 0) || (b.paired ? 1 : 0) - (a.paired ? 1 : 0));
		return list.slice(0, 5);
	}

	readonly property var sink: Pipewire.defaultAudioSink
	readonly property var source: Pipewire.defaultAudioSource
	readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream)
	readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && (n.type & PwNodeType.AudioSource))
	readonly property bool sinkMuted: sink?.audio?.muted ?? false
	readonly property real sinkVolume: sink?.audio?.volume ?? 0

	function nodeLabel(node) {
		if (!node)
			return "None";
		const props = node.properties || {};
		return props["node.description"] || props["node.nickname"] || props["node.name"] || node.nickname || "Unknown device";
	}

	// --- actions --------------------------------------------------------
	function openSection() {
		if (wifiDevice)
			wifiDevice.scannerEnabled = true;
		if (btAdapter)
			btAdapter.discovering = true;
		Brightness.refresh();
		visible = true;
	}

	function toggle() {
		if (visible) {
			visible = false;
		} else {
			openSection();
		}
	}

	onVisibleChanged: {
		if (!visible) {
			if (wifiDevice)
				wifiDevice.scannerEnabled = false;
			if (btAdapter)
				btAdapter.discovering = false;
			pskNetwork = null;
			pskText = "";
			pendingSession = "";
			showOutputs = false;
			showInputs = false;
		}
	}

	function activateNetwork(network) {
		if (!network)
			return;
		if (network.connected) {
			network.disconnect();
			return;
		}
		if (network.known || network.security === WifiSecurityType.Open) {
			pskNetwork = null;
			network.connect();
		} else {
			pskText = "";
			pskNetwork = network;
		}
	}

	function submitPsk() {
		if (pskNetwork && pskText.length > 0) {
			pskNetwork.connectWithPsk(pskText);
			pskNetwork = null;
			pskText = "";
		}
	}

	function activateDevice(device) {
		if (!device)
			return;
		if (device.connected)
			device.connected = false;
		else if (device.paired)
			device.connected = true;
		else
			device.pair();
	}

	function sessionAction(action) {
		if (pendingSession !== action) {
			pendingSession = action;
			sessionTimer.restart();
			return;
		}

		pendingSession = "";
		if (action === "logout")
			Quickshell.execDetached(["niri", "msg", "action", "quit"]);
		else if (action === "suspend")
			Quickshell.execDetached(["systemctl", "suspend"]);
		else if (action === "reboot")
			Quickshell.execDetached(["systemctl", "reboot"]);
		else if (action === "shutdown")
			Quickshell.execDetached(["systemctl", "poweroff"]);
		visible = false;
	}

	Timer {
		id: sessionTimer
		interval: 3000
		repeat: false
		onTriggered: menu.pendingSession = ""
	}

	// --- window content -------------------------------------------------
	// Click anywhere outside the panel to dismiss it.
	MouseArea {
		anchors.fill: parent
		onClicked: menu.visible = false
	}

	Shortcut {
		sequence: "Escape"
		onActivated: menu.visible = false
	}

	Rectangle {
		id: panel
		width: Theme.popupWidth
		height: Math.min(content.implicitHeight + 2 * Theme.popupPadding, menu.maxPanelHeight)
		anchors.top: parent.top
		anchors.topMargin: menu.panelTop
		anchors.right: parent.right
		anchors.rightMargin: 6
		radius: 10
		color: Theme.popupBg
		border.width: 1
		border.color: Theme.border

		// Swallow clicks on the panel background so they don't dismiss it.
		MouseArea {
			anchors.fill: parent
		}

		Flickable {
			id: scroll
			anchors.fill: parent
			anchors.margins: Theme.popupPadding
			contentWidth: width
			contentHeight: content.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: content
				width: scroll.width
				spacing: 10

				// --- top tiles -----------------------------------------------
				Row {
					width: parent.width
					spacing: 8

					Tile {
						width: (parent.width - 8) / 2
						height: 62
						glyph: Theme.icoWifi
						title: "Wi-Fi"
						subtitle: Networking.wifiEnabled
							? (menu.connectedWifi ? menu.connectedWifi.name : "Not connected")
							: "Disabled"
						checked: Networking.wifiEnabled
						onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
					}

					Tile {
						width: (parent.width - 8) / 2
						height: 62
						glyph: Theme.icoBluetooth
						title: "Bluetooth"
						subtitle: !menu.btAdapter
							? "Unavailable"
							: (menu.btAdapter.enabled
								? (menu.btDevices.find(d => d.connected)?.name ?? "On")
								: "Off")
						checked: menu.btAdapter ? menu.btAdapter.enabled : false
						onClicked: {
							if (menu.btAdapter)
								menu.btAdapter.enabled = !menu.btAdapter.enabled;
						}
					}
				}

				// --- wi-fi ---------------------------------------------------
				SectionHeader {
					width: parent.width
					title: "Wi-Fi networks"
					busy: menu.wifiDevice ? menu.wifiDevice.scannerEnabled : false
					toggleVisible: true
					toggleChecked: Networking.wifiEnabled
					onToggled: Networking.wifiEnabled = !Networking.wifiEnabled
				}

				Text {
					visible: !Networking.wifiEnabled
					width: parent.width
					text: "Wi-Fi is turned off"
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 12
				}

				Column {
					width: parent.width
					spacing: 2
					visible: Networking.wifiEnabled

					Repeater {
						model: menu.wifiNetworks
						delegate: NetworkRow {
							required property var modelData
							width: content.width
							network: modelData
							pskActive: menu.pskNetwork === modelData
							onActivated: menu.activateNetwork(modelData)
						}
					}

					Text {
						visible: Networking.wifiEnabled && menu.wifiNetworks.length === 0
						width: parent.width
						text: "No networks found"
						color: Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 12
					}
				}

				// password entry
				Rectangle {
					visible: menu.pskNetwork !== null
					width: parent.width
					height: pskColumn.implicitHeight + 16
					radius: 6
					color: Theme.surface

					Column {
						id: pskColumn
						anchors.left: parent.left
						anchors.right: parent.right
						anchors.top: parent.top
						anchors.margins: 8
						spacing: 6

						Text {
							text: "Password for " + (menu.pskNetwork ? menu.pskNetwork.name : "")
							color: Theme.textDim
							font.family: Theme.fontFamily
							font.pixelSize: 11
						}

						Rectangle {
							width: parent.width
							height: 30
							radius: 5
							color: Theme.surfaceAlt
							border.width: 1
							border.color: pskInput.activeFocus ? Theme.accent : Theme.borderSoft

							TextInput {
								id: pskInput
								anchors.fill: parent
								anchors.leftMargin: 8
								anchors.rightMargin: 8
								verticalAlignment: TextInput.AlignVCenter
								color: Theme.text
								font.family: Theme.fontFamily
								font.pixelSize: 12
								echoMode: TextInput.Password
								passwordCharacter: "•"
								selectionColor: Theme.accent
								onTextChanged: menu.pskText = text
								onAccepted: menu.submitPsk()
								onVisibleChanged: if (visible && menu.pskNetwork) forceActiveFocus()
							}
						}

						Row {
							width: parent.width
							spacing: 8
							anchors.right: parent.right

							Item { width: parent.width - 150; height: 1 }

							MiniButton {
								text: "Cancel"
								onClicked: {
									menu.pskNetwork = null;
									menu.pskText = "";
								}
							}

							MiniButton {
								text: "Connect"
								accent: true
								onClicked: menu.submitPsk()
							}
						}
					}
				}

				Divider { width: parent.width }

				// --- bluetooth -----------------------------------------------
				SectionHeader {
					width: parent.width
					title: "Bluetooth devices"
					busy: menu.btAdapter ? menu.btAdapter.discovering : false
					toggleVisible: menu.btAdapter !== null && menu.btAdapter !== undefined
					toggleChecked: menu.btAdapter ? menu.btAdapter.enabled : false
					onToggled: {
						if (menu.btAdapter)
							menu.btAdapter.enabled = !menu.btAdapter.enabled;
					}
				}

				Text {
					visible: !menu.btAdapter || !menu.btAdapter.enabled
					width: parent.width
					text: menu.btAdapter ? "Bluetooth is turned off" : "No Bluetooth adapter found"
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 12
				}

				Column {
					width: parent.width
					spacing: 2
					visible: menu.btAdapter && menu.btAdapter.enabled

					Repeater {
						model: menu.btDevices
						delegate: DeviceRow {
							required property var modelData
							width: content.width
							device: modelData
							onActivated: menu.activateDevice(modelData)
						}
					}

					Text {
						visible: menu.btDevices.length === 0
						width: parent.width
						text: "No devices found"
						color: Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 12
					}
				}

				Divider { width: parent.width }

				// --- sound ---------------------------------------------------
				Item {
					width: parent.width
					height: 24

					Text {
						anchors.left: parent.left
						anchors.verticalCenter: parent.verticalCenter
						text: "SOUND"
						color: Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 10
						font.weight: Font.DemiBold
						font.letterSpacing: 0.8
					}

					Text {
						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						text: menu.sinkMuted ? "Muted" : menu.sinkPercent() + "%"
						color: Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 11
					}
				}

				Row {
					width: parent.width
					spacing: 8

					IconButton {
						width: 30
						height: 30
						glyph: menu.sinkMuted ? Theme.icoVolumeMute : Theme.icoVolumeHigh
						active: !menu.sinkMuted
						onClicked: {
							if (menu.sink)
								menu.sink.audio.muted = !menu.sink.audio.muted;
						}
					}

					BarSlider {
						id: volumeSlider
						width: parent.width - 30 - 8 - 46
						height: 30
						value: menu.sinkVolume
						onMoved: v => {
							if (menu.sink)
								menu.sink.audio.volume = v;
						}
					}

					Text {
						width: 46
						height: 30
						horizontalAlignment: Text.AlignRight
						verticalAlignment: Text.AlignVCenter
						text: Math.round(volumeSlider.shown * 100) + "%"
						color: Theme.text
						font.family: Theme.fontFamily
						font.pixelSize: 12
					}
				}

				// output device
				DeviceSelector {
					width: parent.width
					label: "Output"
					value: menu.nodeLabel(menu.sink)
					expanded: menu.showOutputs
					onToggled: menu.showOutputs = !menu.showOutputs
				}

				Column {
					width: parent.width
					spacing: 2
					visible: menu.showOutputs

					Repeater {
						model: menu.sinks
						delegate: AudioDeviceRow {
							required property var modelData
							width: content.width
							label: menu.nodeLabel(modelData)
							selected: menu.sink === modelData
							onActivated: {
								Pipewire.preferredDefaultAudioSink = modelData;
								menu.showOutputs = false;
							}
						}
					}
				}

				// input device
				DeviceSelector {
					width: parent.width
					label: "Input"
					value: menu.nodeLabel(menu.source)
					expanded: menu.showInputs
					onToggled: menu.showInputs = !menu.showInputs
				}

				Column {
					width: parent.width
					spacing: 2
					visible: menu.showInputs

					Repeater {
						model: menu.sources
						delegate: AudioDeviceRow {
							required property var modelData
							width: content.width
							label: menu.nodeLabel(modelData)
							selected: menu.source === modelData
							onActivated: {
								Pipewire.preferredDefaultAudioSource = modelData;
								menu.showInputs = false;
							}
						}
					}
				}

				Divider { width: parent.width }

				// --- brightness ---------------------------------------------
				Item {
					width: parent.width
					height: 24

					Text {
						anchors.left: parent.left
						anchors.verticalCenter: parent.verticalCenter
						text: "BRIGHTNESS"
						color: Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 10
						font.weight: Font.DemiBold
						font.letterSpacing: 0.8
					}

					Text {
						anchors.right: parent.right
						anchors.verticalCenter: parent.verticalCenter
						text: Brightness.percent + "%"
						color: Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 11
					}
				}

				Row {
					width: parent.width
					spacing: 8

					IconButton {
						width: 30
						height: 30
						glyph: Theme.icoBrightness
						active: true
						onClicked: Brightness.setPercent(100)
					}

					BarSlider {
						id: brightnessSlider
						width: parent.width - 30 - 8
						height: 30
						value: Brightness.percent / 100
						onMoved: v => Brightness.setPercent(v * 100)
					}
				}

				Divider { width: parent.width }

				// --- session ------------------------------------------------
				Item {
					width: parent.width
					height: 24

					Text {
						anchors.left: parent.left
						anchors.verticalCenter: parent.verticalCenter
						text: "SESSION"
						color: Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 10
						font.weight: Font.DemiBold
						font.letterSpacing: 0.8
					}
				}

				Row {
					width: parent.width
					spacing: 8

					SessionButton {
						width: (parent.width - 24) / 4
						glyph: Theme.icoLogout
						label: menu.pendingSession === "logout" ? "Confirm" : "Logout"
						onClicked: menu.sessionAction("logout")
					}

					SessionButton {
						width: (parent.width - 24) / 4
						glyph: Theme.icoSuspend
						label: menu.pendingSession === "suspend" ? "Confirm" : "Suspend"
						onClicked: menu.sessionAction("suspend")
					}

					SessionButton {
						width: (parent.width - 24) / 4
						glyph: Theme.icoReboot
						label: menu.pendingSession === "reboot" ? "Confirm" : "Reboot"
						danger: true
						onClicked: menu.sessionAction("reboot")
					}

					SessionButton {
						width: (parent.width - 24) / 4
						glyph: Theme.icoShutdown
						label: menu.pendingSession === "shutdown" ? "Confirm" : "Shutdown"
						danger: true
						onClicked: menu.sessionAction("shutdown")
					}
				}
			}
		}
	}

	function sinkPercent() {
		return Math.round(menu.sinkVolume * 100);
	}

	// --- inline components ----------------------------------------------
	component Tile: Rectangle {
		id: tile

		property string glyph: ""
		property string title: ""
		property string subtitle: ""
		property bool checked: false

		signal clicked()

		radius: 8
		color: tile.checked ? Qt.rgba(61 / 255, 174 / 255, 233 / 255, 0.22) : Qt.rgba(1, 1, 1, 0.06)
		border.width: 1
		border.color: tile.checked ? Theme.accentDim : Theme.borderSoft

		Row {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			anchors.leftMargin: 12
			anchors.rightMargin: 10
			spacing: 10

			Rectangle {
				width: 36
				height: 36
				radius: 18
				color: tile.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.08)
				anchors.verticalCenter: parent.verticalCenter

				Text {
					anchors.centerIn: parent
					text: tile.glyph
					color: tile.checked ? Theme.barBg : Theme.text
					font.family: Theme.iconFamily
					font.pixelSize: 17
				}
			}

			Column {
				anchors.verticalCenter: parent.verticalCenter
				width: parent.width - 46
				spacing: 1

				Text {
					text: tile.title
					color: Theme.text
					font.family: Theme.fontFamily
					font.pixelSize: 13
					font.weight: Font.DemiBold
				}

				Text {
					text: tile.subtitle
					width: parent.width
					elide: Text.ElideRight
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 11
				}
			}
		}

		MouseArea {
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: tile.clicked()
		}
	}

	component SectionHeader: Item {
		id: header

		property string title: ""
		property bool busy: false
		property bool toggleVisible: false
		property bool toggleChecked: false

		signal toggled()

		height: 24

		Text {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			text: header.title.toUpperCase()
			color: Theme.textDim
			font.family: Theme.fontFamily
			font.pixelSize: 10
			font.weight: Font.DemiBold
			font.letterSpacing: 0.8
		}

		Text {
			anchors.right: toggle.left
			anchors.rightMargin: 8
			anchors.verticalCenter: parent.verticalCenter
			visible: header.busy
			text: "Scanning…"
			color: Theme.textDim
			font.family: Theme.fontFamily
			font.pixelSize: 10
		}

		ToggleSwitch {
			id: toggle
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			visible: header.toggleVisible
			checked: header.toggleChecked
			onToggled: header.toggled()
		}
	}

	component ToggleSwitch: Item {
		id: sw

		property bool checked: false

		signal toggled()

		implicitWidth: 38
		implicitHeight: 20

		Rectangle {
			anchors.fill: parent
			radius: height / 2
			color: sw.checked ? Theme.accent : Qt.rgba(1, 1, 1, 0.18)
			border.width: 1
			border.color: sw.checked ? Theme.accent : Theme.borderSoft
		}

		Rectangle {
			width: 14
			height: 14
			radius: 7
			y: 3
			x: sw.checked ? parent.width - 17 : 3
			color: sw.checked ? Theme.barBg : Theme.text

			Behavior on x {
				NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
			}
		}

		MouseArea {
			anchors.fill: parent
			cursorShape: Qt.PointingHandCursor
			onClicked: {
				sw.toggled();
			}
		}
	}

	component NetworkRow: Rectangle {
		id: netRow

		property var network: null
		property bool pskActive: false

		signal activated()

		width: parent ? parent.width : 0
		height: netColumn.implicitHeight + 10
		radius: 6
		color: netArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

		Column {
			id: netColumn
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.top: parent.top
			anchors.margins: 5
			spacing: 2

			Row {
				width: parent.width
				spacing: 8

				Text {
					width: 18
					anchors.verticalCenter: parent.verticalCenter
					text: Theme.icoWifi
					color: netRow.network && netRow.network.connected ? Theme.accent : Theme.textDim
					font.family: Theme.iconFamily
					font.pixelSize: 13
				}

				Text {
					width: parent.width - 18 - 8 - 70
					anchors.verticalCenter: parent.verticalCenter
					text: netRow.network ? netRow.network.name : ""
					elide: Text.ElideRight
					color: Theme.text
					font.family: Theme.fontFamily
					font.pixelSize: 12
				}

				Text {
					width: 40
					anchors.verticalCenter: parent.verticalCenter
					horizontalAlignment: Text.AlignRight
					text: netRow.network ? Math.round(netRow.network.signalStrength * 100) + "%" : ""
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 10
				}

				Text {
					width: 14
					anchors.verticalCenter: parent.verticalCenter
					text: netRow.network && netRow.network.connected
						? Theme.icoCheck
						: (netRow.network && netRow.network.state === ConnectionState.Connecting
							? "…"
							: (netRow.network && netRow.network.known ? Theme.icoChevronRight : ""))
					color: netRow.network && netRow.network.connected ? Theme.accent : Theme.textDim
					font.family: Theme.iconFamily
					font.pixelSize: 11
				}
			}

			Row {
				visible: netRow.pskActive
				width: parent.width
				spacing: 6

				Text {
					anchors.verticalCenter: parent.verticalCenter
					text: Theme.icoLock
					color: Theme.textDim
					font.family: Theme.iconFamily
					font.pixelSize: 10
				}

				Text {
					anchors.verticalCenter: parent.verticalCenter
					text: "Password required"
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 10
				}
			}
		}

		MouseArea {
			id: netArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: netRow.activated()
		}
	}

	component DeviceRow: Rectangle {
		id: devRow

		property var device: null

		signal activated()

		width: parent ? parent.width : 0
		height: 34
		radius: 6
		color: devArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : "transparent"

		Row {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			anchors.leftMargin: 6
			anchors.rightMargin: 6
			spacing: 8

			Text {
				width: 18
				anchors.verticalCenter: parent.verticalCenter
				text: Theme.icoBluetooth
				color: devRow.device && devRow.device.connected ? Theme.accent : Theme.textDim
				font.family: Theme.iconFamily
				font.pixelSize: 13
			}

			Column {
				width: parent.width - 18 - 90
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				Text {
					width: parent.width
					text: devRow.device ? (devRow.device.name || devRow.device.deviceName) : ""
					elide: Text.ElideRight
					color: Theme.text
					font.family: Theme.fontFamily
					font.pixelSize: 12
				}

				Text {
					text: devRow.device
						? (devRow.device.connected
							? "Connected"
							: (devRow.device.paired ? "Paired" : "Not paired"))
						: ""
					color: devRow.device && devRow.device.connected ? Theme.accent : Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 10
				}
			}

			Text {
				width: 70
				anchors.verticalCenter: parent.verticalCenter
				horizontalAlignment: Text.AlignRight
				text: devRow.device
					? (devRow.device.connected ? "Disconnect" : (devRow.device.paired ? "Connect" : "Pair"))
					: ""
				color: Theme.accent
				font.family: Theme.fontFamily
				font.pixelSize: 11
			}
		}

		MouseArea {
			id: devArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: devRow.activated()
		}
	}

	component Divider: Rectangle {
		height: 1
		color: Qt.rgba(1, 1, 1, 0.08)
	}

	component MiniButton: Rectangle {
		id: mini

		property string text: ""
		property bool accent: false

		signal clicked()

		width: textItem.implicitWidth + 20
		height: 26
		radius: 5
		color: mini.accent
			? (miniArea.containsMouse ? Qt.lighter(Theme.accent, 1.1) : Theme.accent)
			: (miniArea.containsMouse ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06))

		Text {
			id: textItem
			anchors.centerIn: parent
			text: mini.text
			color: mini.accent ? Theme.barBg : Theme.text
			font.family: Theme.fontFamily
			font.pixelSize: 11
			font.weight: mini.accent ? Font.DemiBold : Font.Normal
		}

		MouseArea {
			id: miniArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: mini.clicked()
		}
	}

	component IconButton: Rectangle {
		id: iconButton

		property string glyph: ""
		property bool active: true

		signal clicked()

		radius: 6
		color: iconArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

		Text {
			anchors.centerIn: parent
			text: iconButton.glyph
			color: iconButton.active ? Theme.text : Theme.textDim
			font.family: Theme.iconFamily
			font.pixelSize: 15
		}

		MouseArea {
			id: iconArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: iconButton.clicked()
		}
	}

	component BarSlider: Item {
		id: slider

		property real value: 0
		property real dragValue: 0
		property bool dragging: false
		readonly property real shown: slider.dragging ? slider.dragValue : Math.max(0, Math.min(1, slider.value))

		signal moved(real value)

		function updateFromX(x) {
			const trackX = slider.width * 0.0;
			const usable = slider.width - 14;
			const v = Math.max(0, Math.min(1, (x - 7) / usable));
			slider.dragValue = v;
			slider.moved(v);
		}

		Rectangle {
			id: track
			anchors.verticalCenter: parent.verticalCenter
			width: parent.width
			height: 5
			radius: 2.5
			color: Qt.rgba(1, 1, 1, 0.14)
		}

		Rectangle {
			anchors.verticalCenter: parent.verticalCenter
			width: 7 + (parent.width - 14) * slider.shown
			height: 5
			radius: 2.5
			color: Theme.accent
		}

		Rectangle {
			width: 14
			height: 14
			radius: 7
			anchors.verticalCenter: parent.verticalCenter
			x: (parent.width - 14) * slider.shown
			color: Theme.text
			border.width: 2
			border.color: Theme.accent
		}

		MouseArea {
			anchors.fill: parent
			anchors.topMargin: -6
			anchors.bottomMargin: -6
			cursorShape: Qt.PointingHandCursor

			onPressed: mouse => {
				slider.dragging = true;
				slider.updateFromX(mouse.x);
			}
			onPositionChanged: mouse => {
				if (slider.dragging)
					slider.updateFromX(mouse.x);
			}
			onReleased: slider.dragging = false
			onCanceled: slider.dragging = false
		}
	}

	component DeviceSelector: Item {
		id: selector

		property string label: ""
		property string value: ""
		property bool expanded: false

		signal toggled()

		height: 28

		Text {
			anchors.left: parent.left
			anchors.verticalCenter: parent.verticalCenter
			text: selector.label
			color: Theme.textDim
			font.family: Theme.fontFamily
			font.pixelSize: 11
		}

		Text {
			anchors.right: chevron.left
			anchors.rightMargin: 6
			anchors.left: leftText.right
			anchors.leftMargin: 8
			anchors.verticalCenter: parent.verticalCenter
			text: selector.value
			elide: Text.ElideRight
			horizontalAlignment: Text.AlignRight
			color: Theme.text
			font.family: Theme.fontFamily
			font.pixelSize: 11
		}

		Text {
			id: leftText
			visible: false
			text: "x"
		}

		Text {
			id: chevron
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			text: selector.expanded ? Theme.icoChevronDown : Theme.icoChevronRight
			color: Theme.textDim
			font.family: Theme.iconFamily
			font.pixelSize: 10
		}

		Rectangle {
			anchors.fill: parent
			color: selectorArea.containsMouse ? Qt.rgba(1, 1, 1, 0.04) : "transparent"
			radius: 5
		}

		MouseArea {
			id: selectorArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: selector.toggled()
		}
	}

	component AudioDeviceRow: Rectangle {
		id: audioRow

		property string label: ""
		property bool selected: false

		signal activated()

		width: parent ? parent.width : 0
		height: 30
		radius: 5
		color: audioArea.containsMouse ? Qt.rgba(1, 1, 1, 0.05) : (audioRow.selected ? Qt.rgba(61 / 255, 174 / 255, 233 / 255, 0.12) : "transparent")

		Row {
			anchors.left: parent.left
			anchors.right: parent.right
			anchors.verticalCenter: parent.verticalCenter
			anchors.leftMargin: 22
			anchors.rightMargin: 8
			spacing: 6

			Text {
				anchors.verticalCenter: parent.verticalCenter
				text: audioRow.selected ? Theme.icoCheck : ""
				color: Theme.accent
				font.family: Theme.iconFamily
				font.pixelSize: 10
				width: 12
			}

			Text {
				width: parent.width - 18
				anchors.verticalCenter: parent.verticalCenter
				text: audioRow.label
				elide: Text.ElideRight
				color: Theme.text
				font.family: Theme.fontFamily
				font.pixelSize: 11
			}
		}

		MouseArea {
			id: audioArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: audioRow.activated()
		}
	}

	component SessionButton: Rectangle {
		id: sessionButton

		property string glyph: ""
		property string label: ""
		property bool danger: false

		signal clicked()

		height: 52
		radius: 7
		color: sessionArea.containsMouse
			? (sessionButton.danger ? Qt.rgba(218 / 255, 68 / 255, 83 / 255, 0.18) : Qt.rgba(1, 1, 1, 0.08))
			: Qt.rgba(1, 1, 1, 0.05)

		Column {
			anchors.centerIn: parent
			spacing: 4

			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				text: sessionButton.glyph
				color: sessionButton.danger ? Theme.danger : Theme.text
				font.family: Theme.iconFamily
				font.pixelSize: 15
			}

			Text {
				anchors.horizontalCenter: parent.horizontalCenter
				text: sessionButton.label
				color: sessionButton.danger ? Theme.danger : Theme.textDim
				font.family: Theme.fontFamily
				font.pixelSize: 10
			}
		}

		MouseArea {
			id: sessionArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: sessionButton.clicked()
		}
	}
}