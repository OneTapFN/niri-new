import QtQuick
import Quickshell
import Quickshell.Wayland

// Calendar dropdown opened by clicking the clock: a month grid with the
// current day highlighted. Like MediaMenu and WeatherMenu this is a
// fullscreen overlay layer surface, because Qt 6.8 cannot create an
// xdg_popup from a layer-shell parent.
PanelWindow {
	id: calendarMenu

	visible: false
	color: "transparent"
	exclusionMode: ExclusionMode.Ignore
	WlrLayershell.layer: WlrLayer.Overlay
	WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
	WlrLayershell.namespace: "quickshell-calendar"

	anchors {
		top: true
		bottom: true
		left: true
		right: true
	}

	// --- calendar state --------------------------------------------------
	// The month shown in the grid; resets to the current month on open.
	property int viewYear: new Date().getFullYear()
	property int viewMonth: new Date().getMonth() // 0-11

	readonly property var monthNames: [
		"Январь", "Февраль", "Март", "Апрель", "Май", "Июнь",
		"Июль", "Август", "Сентябрь", "Октябрь", "Ноябрь", "Декабрь"
	]
	readonly property var weekdayNames: ["Пн", "Вт", "Ср", "Чт", "Пт", "Сб", "Вс"]

	readonly property var today: new Date()
	readonly property bool showingCurrentMonth:
		viewYear === today.getFullYear() && viewMonth === today.getMonth()

	function toggle() {
		if (visible) {
			visible = false;
		} else {
			goToday();
			visible = true;
		}
	}

	// Offset of the 1st of the month on a Monday-first grid (0-6).
	function weekdayOffset(year, month) {
		return (new Date(year, month, 1).getDay() + 6) % 7;
	}

	function daysInMonth(year, month) {
		return new Date(year, month + 1, 0).getDate();
	}

	function goPrevious() {
		if (viewMonth === 0) {
			viewYear--;
			viewMonth = 11;
		} else {
			viewMonth--;
		}
	}

	function goNext() {
		if (viewMonth === 11) {
			viewYear++;
			viewMonth = 0;
		} else {
			viewMonth++;
		}
	}

	function goToday() {
		const now = new Date();
		viewYear = now.getFullYear();
		viewMonth = now.getMonth();
	}

	MouseArea {
		anchors.fill: parent
		onClicked: calendarMenu.visible = false
	}

	Shortcut {
		sequence: "Escape"
		onActivated: calendarMenu.visible = false
	}

	Rectangle {
		id: panel
		width: 300
		height: contentColumn.implicitHeight + 2 * Theme.popupPadding
		anchors.top: parent.top
		anchors.topMargin: Theme.barHeight + 4
		anchors.horizontalCenter: parent.horizontalCenter
		radius: 10
		color: Theme.popupBg
		border.width: 1
		border.color: Theme.border

		readonly property real cellW: (width - 2 * Theme.popupPadding) / 7

		MouseArea {
			anchors.fill: parent
		}

		Column {
			id: contentColumn
			x: Theme.popupPadding
			y: Theme.popupPadding
			width: parent.width - 2 * Theme.popupPadding
			spacing: 8

			// --- header: month navigation ---------------------------------
			Item {
				width: parent.width
				height: 28

				component NavButton: Item {
					id: navButton

					property string glyph: ""
					signal activated()

					width: 26
					height: parent.height

					Rectangle {
						anchors.fill: parent
						radius: 5
						color: navArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
					}

					Text {
						anchors.centerIn: parent
						text: navButton.glyph
						color: navArea.containsMouse ? Theme.text : Theme.textDim
						font.family: Theme.iconFamily
						font.pixelSize: 13
					}

					MouseArea {
						id: navArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: navButton.activated()
					}
				}

				NavButton {
					id: prevButton
					anchors.left: parent.left
					anchors.verticalCenter: parent.verticalCenter
					glyph: Theme.icoChevronLeft
					onActivated: calendarMenu.goPrevious()
				}

				// Clicking the month name jumps back to today.
				Item {
					id: monthLabel
					width: parent.width - prevButton.width - nextButton.width
					height: parent.height
					anchors.centerIn: parent

					Rectangle {
						anchors.fill: parent
						radius: 5
						color: labelArea.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"
					}

					Text {
						anchors.centerIn: parent
						text: calendarMenu.monthNames[calendarMenu.viewMonth] + " " + calendarMenu.viewYear
						color: calendarMenu.showingCurrentMonth ? Theme.text : Theme.accent
						font.family: Theme.fontFamily
						font.pixelSize: 14
						font.weight: Font.DemiBold
					}

					MouseArea {
						id: labelArea
						anchors.fill: parent
						hoverEnabled: true
						cursorShape: Qt.PointingHandCursor
						onClicked: calendarMenu.goToday()
					}
				}

				NavButton {
					id: nextButton
					anchors.right: parent.right
					anchors.verticalCenter: parent.verticalCenter
					glyph: Theme.icoChevronRight
					onActivated: calendarMenu.goNext()
				}
			}

			// --- weekday names --------------------------------------------
			Row {
				width: parent.width
				spacing: 0

				Repeater {
					model: calendarMenu.weekdayNames

					delegate: Text {
						required property var modelData
						required property int index

						width: panel.cellW
						height: 22
						verticalAlignment: Text.AlignVCenter
						horizontalAlignment: Text.AlignHCenter
						text: modelData
						color: index >= 5 ? Theme.accentDim : Theme.textDim
						font.family: Theme.fontFamily
						font.pixelSize: 11
						font.weight: Font.DemiBold
					}
				}
			}

			// --- day grid: six rows of seven, Monday first ----------------
			Grid {
				width: parent.width
				columns: 7
				rows: 6
				spacing: 2

				Repeater {
					model: 42 // always six full weeks, whatever the offset

					delegate: DayCell { }
				}
			}
		}

		// A single day cell of the month grid.
		component DayCell: Item {
			id: cell

			required property int index

			readonly property int day: cell.index - calendarMenu.weekdayOffset(calendarMenu.viewYear, calendarMenu.viewMonth) + 1
			readonly property bool inMonth: day >= 1 && day <= calendarMenu.daysInMonth(calendarMenu.viewYear, calendarMenu.viewMonth)
			readonly property date cellDate: new Date(calendarMenu.viewYear, calendarMenu.viewMonth, Math.max(1, day))
			readonly property bool isToday: cell.inMonth
				&& cellDate.getFullYear() === calendarMenu.today.getFullYear()
				&& cellDate.getMonth() === calendarMenu.today.getMonth()
				&& cellDate.getDate() === calendarMenu.today.getDate()

			width: panel.cellW
			height: panel.cellW

			Rectangle {
				anchors.centerIn: parent
				width: 28
				height: 28
				radius: height / 2
				color: cell.isToday
					? Theme.accent
					: (cell.inMonth && cellHover.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent")
			}

			Text {
				anchors.centerIn: parent
				text: cell.inMonth ? cell.day : ""
				color: cell.isToday ? Theme.barBg : (cell.inMonth ? Theme.text : Theme.textFaint)
				font.family: Theme.fontFamily
				font.pixelSize: 12
				font.weight: cell.isToday ? Font.DemiBold : Font.Normal
			}

			MouseArea {
				id: cellHover
				anchors.fill: parent
				hoverEnabled: true
				cursorShape: cell.isToday ? Qt.PointingHandCursor : Qt.ArrowCursor
			}
		}
	}
}
