pragma Singleton

import QtQuick
import Quickshell

// Breeze Dark palette shared by every component of the panel.
// Values are taken from the old Waybar configuration so the look is preserved.
Singleton {
	id: theme

	// --- Colors ---------------------------------------------------------
	readonly property color barBg: "#232629" // opaque Breeze Dark
	readonly property color popupBg: "#31363b"
	readonly property color surface: "#31363b"
	readonly property color surfaceAlt: "#3b4045"
	readonly property color accent: "#3daee9"
	readonly property color accentDim: "#2a7ba3"
	readonly property color text: "#eff0f1"
	readonly property color textDim: "#7f8c8d"
	readonly property color textFaint: "#4b4e52"
	readonly property color danger: "#da4453"
	readonly property color warning: "#f67400"
	readonly property color border: "#403daee9"
	readonly property color borderSoft: "#4b4e52"

	// --- Metrics --------------------------------------------------------
	readonly property int barHeight: 34
	readonly property int radius: 6
	readonly property int popupWidth: 380
	readonly property int popupPadding: 12

	// --- Fonts ----------------------------------------------------------
	readonly property string fontFamily: "Noto Sans"
	readonly property string iconFamily: "FontAwesome"
	readonly property int fontSize: 13

	// --- Font Awesome glyphs -------------------------------------------
	readonly property string icoWifi: "\uf1eb"
	readonly property string icoEthernet: "\uf0e8"
	readonly property string icoWifiOff: "\uf1eb"
	readonly property string icoBluetooth: "\uf293"
	readonly property string icoVolumeHigh: "\uf028"
	readonly property string icoVolumeLow: "\uf027"
	readonly property string icoVolumeMute: "\uf026"
	readonly property string icoMic: "\uf130"
	readonly property string icoMicMute: "\uf131"
	readonly property string icoBrightness: "\uf185"
	readonly property string icoBatteryFull: "\uf240"
	readonly property string icoBatteryThree: "\uf241"
	readonly property string icoBatteryHalf: "\uf242"
	readonly property string icoBatteryQuarter: "\uf243"
	readonly property string icoBatteryEmpty: "\uf244"
	readonly property string icoCharging: "\uf0e7"
	readonly property string icoPlugged: "\uf1e6"
	readonly property string icoPower: "\uf011"
	readonly property string icoLock: "\uf023"
	readonly property string icoLogout: "\uf08b"
	readonly property string icoSuspend: "\uf186"
	readonly property string icoReboot: "\uf021"
	readonly property string icoShutdown: "\uf011"
	readonly property string icoCheck: "\uf00c"
	readonly property string icoRefresh: "\uf021"
	readonly property string icoChevronDown: "\uf078"
	readonly property string icoChevronLeft: "\uf053"
	readonly property string icoChevronRight: "\uf054"
	readonly property string icoSignal: "\uf012"
	readonly property string icoDot: "\uf111"
	readonly property string icoRing: "\uf10c"
	readonly property string icoMusic: "\uf001"
	readonly property string icoPlay: "\uf04b"
	readonly property string icoPause: "\uf04c"
	readonly property string icoPrevious: "\uf048"
	readonly property string icoNext: "\uf051"
	readonly property string icoWeatherSun: "\uf185"
	readonly property string icoWeatherMoon: "\uf186"
	readonly property string icoWeatherCloud: "\uf0c2"
	readonly property string icoWeatherRain: "\uf043"
	readonly property string icoWeatherSnow: "\uf2dc"
	readonly property string icoWeatherThunder: "\uf0e7"
	readonly property string icoWeatherQuestion: "\uf059"
}