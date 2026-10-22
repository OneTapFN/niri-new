import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import Quickshell.Services.Mpris

// Media dropdown: application name, cover art and the current track.
//
// Like QuickMenu this is a fullscreen overlay layer surface, because Qt 6.8
// cannot create an xdg_popup from a layer-shell parent.
PanelWindow {
	id: mediaMenu

	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-media"

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	readonly property real panelTop: Theme.barHeight + 4
	readonly property real maxPanelHeight: Math.max(240, height - panelTop - 12)

	function toggle() {
		if (visible) {
			visible = false;
		} else {
			if (NowPlaying.player)
				NowPlaying.player.positionChanged();
			visible = true;
		}
	}

	function formatTime(value) {
		if (!isFinite(value) || value <= 0)
			return "0:00";
		const total = Math.floor(value);
		const hours = Math.floor(total / 3600);
		const minutes = Math.floor((total % 3600) / 60);
		const seconds = total % 60;
		const padded = seconds < 10 ? "0" + seconds : "" + seconds;
		if (hours > 0) {
			const paddedMinutes = minutes < 10 ? "0" + minutes : "" + minutes;
			return hours + ":" + paddedMinutes + ":" + padded;
		}
		return minutes + ":" + padded;
	}

	// Refresh the progress bar while the menu is open.
	Timer {
		interval: 1000
		repeat: true
		running: mediaMenu.visible && NowPlaying.playing
		onTriggered: {
			if (NowPlaying.player)
				NowPlaying.player.positionChanged();
		}
	}

	Connections {
		target: NowPlaying
		function onHasPlayerChanged() {
			if (!NowPlaying.hasPlayer)
				mediaMenu.visible = false;
		}
	}

	MouseArea {
		anchors.fill: parent
		onClicked: mediaMenu.visible = false
	}

	Shortcut {
		sequence: "Escape"
		onActivated: mediaMenu.visible = false
	}

	Rectangle {
		id: panel
		width: Theme.popupWidth
		height: Math.min(contentColumn.implicitHeight + 2 * Theme.popupPadding, mediaMenu.maxPanelHeight)
		anchors.top: parent.top
		anchors.topMargin: mediaMenu.panelTop
		anchors.horizontalCenter: parent.horizontalCenter
		radius: 10
		color: Theme.popupBg
		border.width: 1
		border.color: Theme.border

		MouseArea {
			anchors.fill: parent
		}

		Flickable {
			id: scroll
			anchors.fill: parent
			anchors.margins: Theme.popupPadding
			contentWidth: width
			contentHeight: contentColumn.implicitHeight
			clip: true
			boundsBehavior: Flickable.StopAtBounds

			Column {
				id: contentColumn
				width: scroll.width
				spacing: 10

				// --- application name (top) ------------------------------
				Row {
					width: parent.width
					spacing: 8
					height: 20

					IconImage {
						anchors.verticalCenter: parent.verticalCenter
						implicitSize: 16
						source: NowPlaying.appIcon
					}

					Text {
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width - 24
						text: NowPlaying.appName
						elide: Text.ElideRight
						color: Theme.accent
						font.family: Theme.fontFamily
						font.pixelSize: 12
						font.weight: Font.DemiBold
					}
				}

				// --- cover art -------------------------------------------
				ClippingRectangle {
					id: cover
					width: parent.width
					// Keep the original aspect ratio, within sensible bounds.
					height: Math.min(320, Math.max(150, width * artRatio))
					radius: 8
					color: Theme.surfaceAlt
					border.width: 0

					readonly property real artRatio: art.status === Image.Ready && art.sourceSize.width > 0
						? art.sourceSize.height / art.sourceSize.width
						: 0.5625

					Image {
						id: art
						anchors.fill: parent
						source: NowPlaying.artUrl
						fillMode: Image.PreserveAspectCrop
						asynchronous: true
						cache: false
						visible: status === Image.Ready
					}

					Column {
						anchors.centerIn: parent
						spacing: 8
						visible: art.status !== Image.Ready

						Text {
							anchors.horizontalCenter: parent.horizontalCenter
							text: Theme.icoMusic
							color: Theme.textFaint
							font.family: Theme.iconFamily
							font.pixelSize: 42
						}

						Text {
							anchors.horizontalCenter: parent.horizontalCenter
							text: "No artwork"
							color: Theme.textDim
							font.family: Theme.fontFamily
							font.pixelSize: 11
						}
					}

					// Paused badge on the cover.
					Rectangle {
						visible: !NowPlaying.playing && art.status === Image.Ready
						anchors.right: parent.right
						anchors.bottom: parent.bottom
						anchors.margins: 8
						width: 28
						height: 28
						radius: 14
						color: Qt.rgba(35 / 255, 38 / 255, 41 / 255, 0.85)

						Text {
							anchors.centerIn: parent
							text: Theme.icoPause
							color: Theme.text
							font.family: Theme.iconFamily
							font.pixelSize: 11
						}
					}
				}

				// --- title and artist ------------------------------------
				Text {
					width: parent.width
					text: NowPlaying.title || "Unknown title"
					color: Theme.text
					font.family: Theme.fontFamily
					font.pixelSize: 17
					font.weight: Font.DemiBold
					wrapMode: Text.Wrap
					maximumLineCount: 2
					elide: Text.ElideRight
				}

				Text {
					width: parent.width
					text: NowPlaying.artist || "Unknown artist"
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 13
					wrapMode: Text.Wrap
					maximumLineCount: 2
					elide: Text.ElideRight
				}

				Text {
					width: parent.width
					visible: text !== ""
					text: NowPlaying.album
					color: Theme.textFaint
					font.family: Theme.fontFamily
					font.pixelSize: 11
					elide: Text.ElideRight
				}

				// --- progress --------------------------------------------
				Column {
					width: parent.width
					spacing: 4
					visible: NowPlaying.length > 0

					Item {
						width: parent.width
						height: 4

						Rectangle {
							anchors.verticalCenter: parent.verticalCenter
							width: parent.width
							height: 3
							radius: 1.5
							color: Theme.surfaceAlt
						}

						Rectangle {
							anchors.verticalCenter: parent.verticalCenter
							width: parent.width * Math.min(1, Math.max(0, NowPlaying.length > 0 ? NowPlaying.position / NowPlaying.length : 0))
							height: 3
							radius: 1.5
							color: Theme.accent
						}
					}

					Row {
						width: parent.width

						Text {
							id: elapsed
							text: mediaMenu.formatTime(NowPlaying.position)
							color: Theme.textDim
							font.family: Theme.fontFamily
							font.pixelSize: 10
						}

						Item {
							width: Math.max(0, parent.width - elapsed.implicitWidth - total.implicitWidth)
							height: 1
						}

						Text {
							id: total
							text: mediaMenu.formatTime(NowPlaying.length)
							color: Theme.textDim
							font.family: Theme.fontFamily
							font.pixelSize: 10
						}
					}
				}

				// --- playback controls -----------------------------------
				Row {
					anchors.horizontalCenter: parent.horizontalCenter
					spacing: 14

					MediaButton {
						glyph: Theme.icoPrevious
						enabled: NowPlaying.player ? NowPlaying.player.canGoPrevious : false
						onClicked: if (NowPlaying.player) NowPlaying.player.previous()
					}

					Rectangle {
						width: 40
						height: 40
						radius: 20
						color: playArea.containsMouse ? Qt.lighter(Theme.accent, 1.12) : Theme.accent
						opacity: NowPlaying.player && NowPlaying.player.canTogglePlaying ? 1 : 0.4

						Text {
							anchors.centerIn: parent
							text: NowPlaying.playing ? Theme.icoPause : Theme.icoPlay
							color: Theme.barBg
							font.family: Theme.iconFamily
							font.pixelSize: 15
						}

						MouseArea {
							id: playArea
							anchors.fill: parent
							hoverEnabled: true
							enabled: NowPlaying.player ? NowPlaying.player.canTogglePlaying : false
							cursorShape: Qt.PointingHandCursor
							onClicked: if (NowPlaying.player) NowPlaying.player.togglePlaying()
						}
					}

					MediaButton {
						glyph: Theme.icoNext
						enabled: NowPlaying.player ? NowPlaying.player.canGoNext : false
						onClicked: if (NowPlaying.player) NowPlaying.player.next()
					}
				}
			}
		}
	}

	component MediaButton: Item {
		id: button

		property string glyph: ""
		signal clicked()

		implicitWidth: 36
		implicitHeight: 36
		opacity: button.enabled ? 1 : 0.35

		Rectangle {
			anchors.fill: parent
			radius: 18
			color: buttonArea.containsMouse && button.enabled ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
		}

		Text {
			anchors.centerIn: parent
			text: button.glyph
			color: Theme.text
			font.family: Theme.iconFamily
			font.pixelSize: 15
		}

		MouseArea {
			id: buttonArea
			anchors.fill: parent
			hoverEnabled: true
			enabled: button.enabled
			cursorShape: Qt.PointingHandCursor
			onClicked: button.clicked()
		}
	}
}
