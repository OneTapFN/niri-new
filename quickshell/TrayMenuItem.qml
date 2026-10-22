import QtQuick
import Quickshell

// A single row of a tray menu (or a separator).
Item {
	id: row

	property var entry: null

	signal activated(var entry)

	width: parent ? parent.width : 0
	height: entry && entry.isSeparator ? 1 : 28

	Rectangle {
		visible: row.entry && row.entry.isSeparator
		anchors.verticalCenter: parent.verticalCenter
		width: parent.width
		height: 1
		color: Qt.rgba(1, 1, 1, 0.10)
	}

	Rectangle {
		visible: row.entry && !row.entry.isSeparator
		anchors.fill: parent
		radius: 5
		color: rowArea.containsMouse && row.entry && row.entry.enabled
			? Qt.rgba(1, 1, 1, 0.08)
			: "transparent"
	}

	Row {
		visible: row.entry && !row.entry.isSeparator
		anchors.left: parent.left
		anchors.leftMargin: 8
		anchors.right: parent.right
		anchors.rightMargin: 8
		anchors.verticalCenter: parent.verticalCenter
		spacing: 8

		Text {
			width: 14
			anchors.verticalCenter: parent.verticalCenter
			text: row.entry && row.entry.buttonType !== QsMenuButtonType.None
				? (row.entry.checkState === Qt.Checked ? Theme.icoCheck : "")
				: ""
			color: Theme.accent
			font.family: Theme.iconFamily
			font.pixelSize: 10
		}

		Text {
			width: parent.width - 14 - 8 - (row.entry && row.entry.hasChildren ? 14 : 0) - 8
			anchors.verticalCenter: parent.verticalCenter
			text: row.entry && row.entry.text ? row.entry.text.replace(/&/g, "") : ""
			elide: Text.ElideRight
			color: row.entry && row.entry.enabled ? Theme.text : Theme.textDim
			font.family: Theme.fontFamily
			font.pixelSize: 12
		}

		Text {
			width: 14
			visible: row.entry && row.entry.hasChildren
			anchors.verticalCenter: parent.verticalCenter
			text: Theme.icoChevronRight
			color: Theme.textDim
			font.family: Theme.iconFamily
			font.pixelSize: 9
		}
	}

	MouseArea {
		id: rowArea
		anchors.fill: parent
		enabled: row.entry && !row.entry.isSeparator
		hoverEnabled: true
		cursorShape: Qt.PointingHandCursor
		onClicked: row.activated(row.entry)
	}
}
