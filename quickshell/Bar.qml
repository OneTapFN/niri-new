import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Bluetooth
import Quickshell.Networking
import Quickshell.Widgets

// Top panel: workspaces, window title, clock and the GNOME style status area.
PanelWindow {
	id: bar

	// Set by shell.qml so the status buttons can toggle the quick menu.
	property var quickMenu: null
	// Set by shell.qml, shows context menus for system tray items.
	property var trayMenu: null
	// Set by shell.qml, the media dropdown opened from the center of the bar.
	property var mediaMenu: null
	// Set by shell.qml, the weather dropdown opened from the weather pill.
	property var weatherMenu: null
	// Set by shell.qml, the calendar dropdown opened from the clock pill.
	property var calendarMenu: null

	anchors {
		top: true
		left: true
		right: true
	}

	implicitHeight: Theme.barHeight
	exclusiveZone: Theme.barHeight
	color: Theme.barBg

	// --- status sources -------------------------------------------------
	readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi)
	readonly property var wifiNetwork: wifiDevice ? wifiDevice.networks.values.find(n => n.connected) : null
	readonly property bool wifiConnected: wifiNetwork !== null && wifiNetwork !== undefined
	readonly property var btAdapter: Bluetooth.defaultAdapter
	readonly property var btConnectedDevice: {
		if (!btAdapter)
			return null;
		return btAdapter.devices.values.find(d => d.connected) ?? null;
	}
	readonly property var sink: Pipewire.defaultAudioSink
	readonly property bool sinkMuted: sink?.audio?.muted ?? false
	readonly property int sinkPercent: Math.round((sink?.audio?.volume ?? 0) * 100)
	readonly property var battery: UPower.displayDevice
	readonly property int batteryPercent: battery ? Math.round(battery.percentage * 100) : -1

	PwObjectTracker {
		objects: [Pipewire.defaultAudioSink]
	}

	function batteryGlyph() {
		if (!battery)
			return Theme.icoBatteryFull;
		if (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.PendingCharge)
			return Theme.icoCharging;
		if (battery.state === UPowerDeviceState.FullyCharged)
			return Theme.icoPlugged;
		if (batteryPercent >= 90) return Theme.icoBatteryFull;
		if (batteryPercent >= 65) return Theme.icoBatteryThree;
		if (batteryPercent >= 40) return Theme.icoBatteryHalf;
		if (batteryPercent >= 15) return Theme.icoBatteryQuarter;
		return Theme.icoBatteryEmpty;
	}

	function toggleMenu() {
		if (bar.mediaMenu)
			bar.mediaMenu.visible = false;
		if (bar.calendarMenu)
			bar.calendarMenu.visible = false;
		if (bar.quickMenu)
			bar.quickMenu.toggle();
	}

	function toggleMediaMenu() {
		if (bar.quickMenu)
			bar.quickMenu.visible = false;
		if (bar.calendarMenu)
			bar.calendarMenu.visible = false;
		if (bar.weatherMenu)
			bar.weatherMenu.visible = false;
		if (bar.mediaMenu)
			bar.mediaMenu.toggle();
	}

	function toggleWeatherMenu() {
		if (bar.quickMenu)
			bar.quickMenu.visible = false;
		if (bar.mediaMenu)
			bar.mediaMenu.visible = false;
		if (bar.calendarMenu)
			bar.calendarMenu.visible = false;
		if (bar.weatherMenu)
			bar.weatherMenu.toggle();
	}

	function toggleCalendarMenu() {
		if (bar.quickMenu)
			bar.quickMenu.visible = false;
		if (bar.mediaMenu)
			bar.mediaMenu.visible = false;
		if (bar.weatherMenu)
			bar.weatherMenu.visible = false;
		if (bar.calendarMenu)
			bar.calendarMenu.toggle();
	}

	function openTrayMenu(item, visual) {
		if (!item)
			return;
		if (!item.menu) {
			item.activate();
			return;
		}
		if (!bar.trayMenu)
			return;
		const pos = visual
			? visual.mapToItem(null, visual.width / 2, visual.height)
			: Qt.point(bar.width - 30, bar.height);
		bar.trayMenu.openFor(item.menu, pos.x, bar.height + 2);
	}


	// --- left: workspaces + focused window ------------------------------
	Row {
		id: leftRow
		anchors.left: parent.left
		anchors.leftMargin: 6
		anchors.verticalCenter: parent.verticalCenter
		spacing: 2

		Repeater {
			model: Niri.sortedWorkspaces
			delegate: WorkspaceDot {
				required property var modelData
				ws: modelData
			}
		}

		Item {
			width: 6
			height: 1
		}

		Text {
			id: windowTitle
			anchors.verticalCenter: parent.verticalCenter
			text: Niri.focusedTitle
			visible: text !== ""
			width: Math.min(implicitWidth, 420)
			elide: Text.ElideRight
			color: "#bdc3c7"
			font.family: Theme.fontFamily
			font.pixelSize: Theme.fontSize
		}
	}

	// --- center: now playing + clock -------------------------------------
	Row {
		id: centerRow
		anchors.centerIn: parent
		spacing: 8

		MediaPill {
			visible: (NowPlaying.hasPlayer && NowPlaying.title !== "") || MusicSpectrum.forceRun
		}

		// Weather in Pavlovsky Posad, sits between the media pill and the clock.
		WeatherPill { }

		Rectangle {
			id: clockPill
			width: clockText.implicitWidth + 24
			height: 26
			radius: 6
			color: Qt.rgba(61 / 255, 174 / 255, 233 / 255, 0.14)

			Text {
				id: clockText
				anchors.centerIn: parent
				text: Qt.formatTime(clock.date, "HH:mm")
				color: Theme.text
				font.family: Theme.fontFamily
				font.pixelSize: Theme.fontSize
				font.weight: Font.DemiBold
			}

			MouseArea {
				anchors.fill: parent
				cursorShape: Qt.PointingHandCursor
				onClicked: bar.toggleCalendarMenu()
			}
		}
	}

	// --- right: tray, layout, quick settings ----------------------------
	Row {
		id: rightRow
		anchors.right: parent.right
		anchors.rightMargin: 6
		anchors.verticalCenter: parent.verticalCenter
		spacing: 2

		Row {
			id: trayRow
			anchors.verticalCenter: parent.verticalCenter
			spacing: 2

			Repeater {
				model: SystemTray.items

				delegate: Item {
					id: trayItem
					required property var modelData

					width: 24
					height: 24

					Rectangle {
						anchors.fill: parent
						radius: 5
						color: trayArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
					}

					IconImage {
						anchors.centerIn: parent
						implicitSize: 16
						source: trayItem.modelData.icon
					}

					MouseArea {
						id: trayArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: bar.openTrayMenu(trayItem.modelData, trayItem)
					}
				}
			}
		}

		Item {
			width: 4
			height: 1
		}

		// Keyboard layout badge (display only, Caps Lock switches it).
		Item {
			width: 30
			height: 26
			anchors.verticalCenter: parent.verticalCenter

			Rectangle {
				anchors.fill: parent
				radius: 5
				color: layoutArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
			}

			Text {
				anchors.centerIn: parent
				text: Niri.layoutCode
				color: Theme.text
				font.family: Theme.fontFamily
				font.pixelSize: 12
				font.weight: Font.DemiBold
			}

			MouseArea {
				id: layoutArea
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: Qt.PointingHandCursor
				onClicked: Quickshell.execDetached(["niri", "msg", "action", "switch-layout", "next"])
			}
		}

		Item {
			width: 4
			height: 1
		}

		// GNOME style status pill.
		Rectangle {
			id: statusPill
			anchors.verticalCenter: parent.verticalCenter
			implicitWidth: statusRow.implicitWidth + 4
			implicitHeight: 28
			radius: 6
			color: Qt.rgba(1, 1, 1, 0.06)

			Row {
				id: statusRow
				anchors.centerIn: parent
				spacing: 0

				StatusButton {
					glyph: bar.wifiConnected ? Theme.icoWifi : Theme.icoWifiOff
					active: Networking.wifiEnabled
					onClicked: bar.toggleMenu()
				}

				StatusButton {
					glyph: Theme.icoBluetooth
					active: bar.btAdapter ? bar.btAdapter.enabled : false
					danger: false
					onClicked: bar.toggleMenu()
				}

				StatusButton {
					glyph: bar.sinkMuted ? Theme.icoVolumeMute : (bar.sinkPercent < 40 ? Theme.icoVolumeLow : Theme.icoVolumeHigh)
					label: bar.sinkMuted ? "muted" : bar.sinkPercent + "%"
					active: !bar.sinkMuted && bar.sinkPercent > 0
					onClicked: bar.toggleMenu()
				}

				StatusButton {
					glyph: Theme.icoBrightness
					label: Brightness.percent + "%"
					active: true
					onClicked: bar.toggleMenu()
				}

				StatusButton {
					glyph: bar.batteryGlyph()
					label: bar.battery ? bar.batteryPercent + "%" : ""
					active: true
					danger: bar.battery !== null && bar.battery !== undefined
						&& bar.batteryPercent <= 15
						&& bar.battery.state !== UPowerDeviceState.Charging
					onClicked: bar.toggleMenu()
				}
			}
		}
	}

	SystemClock {
		id: clock
		precision: SystemClock.Minutes
	}

	// --- inline components ----------------------------------------------
	component MediaPill: Rectangle {
		id: pill

		width: mediaContent.implicitWidth + 14
		height: 28
		radius: 6
		color: mediaArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)

		Row {
			id: mediaContent
			anchors.centerIn: parent
			spacing: 7

			ClippingRectangle {
				width: 20
				height: 20
				radius: 4
				color: Theme.surfaceAlt
				border.width: 0
				anchors.verticalCenter: parent.verticalCenter

				Image {
					id: thumb
					anchors.fill: parent
					source: NowPlaying.artUrl
					fillMode: Image.PreserveAspectCrop
					asynchronous: true
					cache: false
					visible: status === Image.Ready
				}

				Text {
					anchors.centerIn: parent
					visible: thumb.status !== Image.Ready
					text: Theme.icoMusic
					color: Theme.textDim
					font.family: Theme.iconFamily
					font.pixelSize: 9
				}
			}

			Column {
				id: textColumn
				width: Math.min(220, Math.max(pillTitle.implicitWidth, pillArtist.implicitWidth))
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				Text {
					id: pillTitle
					width: parent.width
					text: NowPlaying.title || "Unknown title"
					elide: Text.ElideRight
					color: Theme.text
					font.family: Theme.fontFamily
					font.pixelSize: 11
					font.weight: Font.DemiBold
				}

				Text {
					id: pillArtist
					width: parent.width
					visible: text !== ""
					text: NowPlaying.artist
					elide: Text.ElideRight
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 9
				}
			}

			// Four-band music visualiser, cava style, right of the titles.
			Item {
				width: 18
				height: 20
				anchors.verticalCenter: parent.verticalCenter

				SpectrumBar { x: 0; level: MusicSpectrum.levels[0] }
				SpectrumBar { x: 5; level: MusicSpectrum.levels[1] }
				SpectrumBar { x: 10; level: MusicSpectrum.levels[2] }
				SpectrumBar { x: 15; level: MusicSpectrum.levels[3] }
			}
		}

		MouseArea {
			id: mediaArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: bar.toggleMediaMenu()
		}
	}

	// Four-band music visualiser component (three pixels per bar).
	component SpectrumBar: Rectangle {
		id: bar

		property real level: 0

		width: 3
		anchors.bottom: parent.bottom
		height: 3 + Math.min(1, Math.max(0, bar.level)) * 15
		radius: 1.5
		color: Theme.accent
		opacity: NowPlaying.playing ? 0.95 : 0.3
	}

	// Weather pill: FA glyph, temperature and a short condition description.
	// Click forces an immediate refresh.
	component WeatherPill: Rectangle {
		id: weatherPill

		width: weatherContent.implicitWidth + 14
		height: 28
		radius: 6
		color: weatherArea.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.06)

		Row {
			id: weatherContent
			anchors.centerIn: parent
			spacing: 7

			Text {
				anchors.verticalCenter: parent.verticalCenter
				text: Weather.glyph
				color: Theme.accent
				font.family: Theme.iconFamily
				font.pixelSize: 13
			}

			Column {
				id: weatherText
				width: Math.min(110, Math.max(weatherTemp.implicitWidth, weatherSubtitle.implicitWidth))
				anchors.verticalCenter: parent.verticalCenter
				spacing: 0

				Text {
					id: weatherTemp
					width: parent.width
					text: Weather.tempText
					color: Theme.text
					font.family: Theme.fontFamily
					font.pixelSize: 11
					font.weight: Font.DemiBold
				}

				Text {
					id: weatherSubtitle
					width: parent.width
					visible: text !== ""
					text: Weather.subtitle
					elide: Text.ElideRight
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 9
				}
			}
		}

		MouseArea {
			id: weatherArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: bar.toggleWeatherMenu()
		}
	}

	component StatusButton: Item {
		id: button

		property string glyph: ""
		property string label: ""
		property bool active: true
		property bool danger: false

		signal clicked()

		implicitWidth: buttonRow.implicitWidth + 16
		implicitHeight: 26

		Rectangle {
			anchors.fill: parent
			radius: 5
			color: buttonArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
		}

		Row {
			id: buttonRow
			anchors.centerIn: parent
			spacing: 5

			Text {
				text: button.glyph
				anchors.verticalCenter: parent.verticalCenter
				color: button.danger ? Theme.danger : (button.active ? Theme.text : Theme.textDim)
				font.family: Theme.iconFamily
				font.pixelSize: 14
			}

			Text {
				visible: button.label !== ""
				text: button.label
				anchors.verticalCenter: parent.verticalCenter
				color: button.danger ? Theme.danger : (button.active ? Theme.text : Theme.textDim)
				font.family: Theme.fontFamily
				font.pixelSize: 12
			}
		}

		MouseArea {
			id: buttonArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: button.clicked()
		}
	}

	component WorkspaceDot: Item {
		id: dot

		property var ws: null

		implicitWidth: 26
		implicitHeight: 26

		Rectangle {
			anchors.fill: parent
			radius: 6
			color: dot.ws && dot.ws.is_active
				? Theme.accent
				: (dotArea.containsMouse ? Qt.rgba(61 / 255, 174 / 255, 233 / 255, 0.18) : "transparent")
		}

		Text {
			anchors.centerIn: parent
			text: Theme.icoDot
			color: dot.ws && dot.ws.is_urgent
				? Theme.danger
				: (dot.ws && dot.ws.is_active ? Theme.barBg : Theme.textFaint)
			font.family: Theme.iconFamily
			font.pixelSize: 9
		}

		MouseArea {
			id: dotArea
			anchors.fill: parent
			hoverEnabled: true
			cursorShape: Qt.PointingHandCursor
			onClicked: {
				if (dot.ws)
					Quickshell.execDetached(["niri", "msg", "action", "focus-workspace", "" + dot.ws.idx]);
			}
		}
	}
}