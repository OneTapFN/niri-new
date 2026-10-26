import QtQuick
import Quickshell
import Quickshell.Wayland

// Weather dropdown opened from the weather pill: the current conditions,
// an hourly forecast and the next days.
//
// Like MediaMenu this is a fullscreen overlay layer surface, because Qt 6.8
// cannot create an xdg_popup from a layer-shell parent.
PanelWindow {
	id: weatherMenu

	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-weather"

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
			// Fresh data while opening; refresh() throttles repeated calls.
			Weather.refresh();
			visible = true;
		}
	}

	MouseArea {
		anchors.fill: parent
		onClicked: weatherMenu.visible = false
	}

	Shortcut {
		sequence: "Escape"
		onActivated: weatherMenu.visible = false
	}

	Rectangle {
		id: panel
		width: 340
		height: Math.min(contentColumn.implicitHeight + 2 * Theme.popupPadding, weatherMenu.maxPanelHeight)
		anchors.top: parent.top
		anchors.topMargin: weatherMenu.panelTop
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

				// --- placeholder while there is no data -------------------
				Text {
					width: parent.width
					visible: !Weather.ready
					text: Weather.ready ? "" : (Weather.loading ? "Загрузка…" : "Нет данных о погоде")
					horizontalAlignment: Text.AlignHCenter
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 13
				}

				// --- location and current conditions ----------------------
				Row {
					visible: Weather.ready
					width: parent.width
					spacing: 10

					Text {
						anchors.verticalCenter: parent.verticalCenter
						text: Weather.glyph
						color: Theme.accent
						font.family: Theme.iconFamily
						font.pixelSize: 26
					}

					Column {
						anchors.verticalCenter: parent.verticalCenter
						width: parent.width - 36
						spacing: 2

						Text {
							width: parent.width
							text: "Павловский Посад"
							color: Theme.accent
							font.family: Theme.fontFamily
							font.pixelSize: 12
							font.weight: Font.DemiBold
						}

						Text {
							width: parent.width
							text: Weather.tempText + (Weather.description !== "" ? "  ·  " + Weather.description : "")
							color: Theme.text
							font.family: Theme.fontFamily
							font.pixelSize: 17
							font.weight: Font.DemiBold
							elide: Text.ElideRight
						}
					}
				}

				Rectangle {
					visible: Weather.ready
					width: parent.width
					height: 1
					color: Theme.borderSoft
				}

				// --- hourly forecast --------------------------------------
				Text {
					visible: Weather.ready
					width: parent.width
					text: "Почасовой прогноз"
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 11
					font.weight: Font.DemiBold
				}

				Column {
					visible: Weather.ready
					width: parent.width
					spacing: 2

					Repeater {
						model: Weather.hourly

						delegate: Row {
							id: hourRow
							width: parent.width
							height: 22
							required property int index
							required property var modelData

							// First entry is the current hour.
							readonly property bool isNow: hourRow.index === 0

							Text {
								anchors.verticalCenter: parent.verticalCenter
								width: 40
								text: Qt.formatDateTime(hourRow.modelData.time, "HH:mm")
								color: hourRow.isNow ? Theme.accent : Theme.textDim
								font.family: Theme.fontFamily
								font.pixelSize: 12
								font.weight: hourRow.isNow ? Font.DemiBold : Font.Normal
							}

							Text {
								anchors.verticalCenter: parent.verticalCenter
								width: 20
								text: Weather.glyphFor(hourRow.modelData.symbol)
								color: Theme.accent
								font.family: Theme.iconFamily
								font.pixelSize: 13
							}

							Text {
								anchors.verticalCenter: parent.verticalCenter
								width: 56
								text: Weather.fmtTemp(hourRow.modelData.temp)
								color: Theme.text
								font.family: Theme.fontFamily
								font.pixelSize: 12
								font.weight: hourRow.isNow ? Font.DemiBold : Font.Normal
							}

							Item {
								width: parent.width - 40 - 20 - 56 - 3 * parent.spacing
								height: parent.height

								Row {
									anchors.right: parent.right
									anchors.verticalCenter: parent.verticalCenter
									spacing: 4

									Text {
										anchors.verticalCenter: parent.verticalCenter
										text: Theme.icoWeatherRain
										visible: Weather.fmtPrecip(hourRow.modelData.precip) !== ""
										color: Theme.textDim
										font.family: Theme.iconFamily
										font.pixelSize: 10
									}

									Text {
										anchors.verticalCenter: parent.verticalCenter
										text: Weather.fmtPrecip(hourRow.modelData.precip) !== "" ? Weather.fmtPrecip(hourRow.modelData.precip) + " мм" : ""
										color: Theme.textDim
										font.family: Theme.fontFamily
										font.pixelSize: 11
									}
								}
							}
						}
					}
				}

				Rectangle {
					visible: Weather.ready
					width: parent.width
					height: 1
					color: Theme.borderSoft
				}

				// --- several days ahead -----------------------------------
				Text {
					visible: Weather.ready
					width: parent.width
					text: "На несколько дней"
					color: Theme.textDim
					font.family: Theme.fontFamily
					font.pixelSize: 11
					font.weight: Font.DemiBold
				}

				Column {
					visible: Weather.ready
					width: parent.width
					spacing: 2

					Repeater {
						model: Weather.daily

						delegate: Row {
							id: dayRow
							width: parent.width
							height: 24
							required property int index
							required property var modelData

							readonly property string label: index === 0
								? "Сегодня"
								: Weather.dayNames[dayRow.modelData.time.getDay()] + "  " + Qt.formatDateTime(dayRow.modelData.time, "dd.MM")

							Text {
								anchors.verticalCenter: parent.verticalCenter
								width: 88
								text: dayRow.label
								color: dayRow.index === 0 ? Theme.accent : Theme.text
								font.family: Theme.fontFamily
								font.pixelSize: 12
								font.weight: dayRow.index === 0 ? Font.DemiBold : Font.Normal
							}

							Text {
								anchors.verticalCenter: parent.verticalCenter
								width: 20
								text: Weather.glyphFor(dayRow.modelData.symbol)
								color: Theme.accent
								font.family: Theme.iconFamily
								font.pixelSize: 13
							}

							Item {
								width: parent.width - 88 - 20 - 56 - 3 * parent.spacing
								height: parent.height

								Row {
									anchors.verticalCenter: parent.verticalCenter
									spacing: 5

									Text {
										anchors.verticalCenter: parent.verticalCenter
										text: Weather.fmtTemp(dayRow.modelData.min)
										color: Theme.textDim
										font.family: Theme.fontFamily
										font.pixelSize: 12
									}

									Text {
										anchors.verticalCenter: parent.verticalCenter
										text: "…"
										color: Theme.textFaint
										font.family: Theme.fontFamily
										font.pixelSize: 12
									}

									Text {
										anchors.verticalCenter: parent.verticalCenter
										text: Weather.fmtTemp(dayRow.modelData.max)
										color: Theme.text
										font.family: Theme.fontFamily
										font.pixelSize: 12
										font.weight: Font.DemiBold
									}
								}
							}

							Item {
								width: 56
								height: parent.height

								Row {
									anchors.right: parent.right
									anchors.verticalCenter: parent.verticalCenter
									spacing: 4

									Text {
										anchors.verticalCenter: parent.verticalCenter
										text: Theme.icoWeatherRain
										visible: Weather.fmtPrecip(dayRow.modelData.precip) !== ""
										color: Theme.textDim
										font.family: Theme.iconFamily
										font.pixelSize: 10
									}

									Text {
										anchors.verticalCenter: parent.verticalCenter
										text: Weather.fmtPrecip(dayRow.modelData.precip) !== "" ? Weather.fmtPrecip(dayRow.modelData.precip) + " мм" : ""
										color: Theme.textDim
										font.family: Theme.fontFamily
										font.pixelSize: 11
									}
								}
							}
						}
					}
				}

				// --- updated timestamp ------------------------------------
				Text {
					visible: Weather.lastFetch !== null
					width: parent.width
					text: visible ? "Обновлено в " + Qt.formatDateTime(Weather.lastFetch, "HH:mm") : ""
					color: Theme.textFaint
					font.family: Theme.fontFamily
					font.pixelSize: 10
				}
			}
		}
	}
}
