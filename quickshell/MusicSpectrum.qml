pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Four-band music spectrum for the media pill.
//
// scripts/music-spectrum.py runs the capture and the FFT (numpy in C land)
// and prints one line of raw band dB values per ~33 ms frame; this singleton
// applies the per-band gain, normalises into 0..1 levels and smooths them
// with a cava-like sharp attack / smooth decay.
Singleton {
	id: musicSpectrum

	// Normalised 0..1 levels: bass, low-mid, mid, high (decaying between frames).
	property var levels: [0, 0, 0, 0]

	// Raw dB values of the latest frame from the capture script.
	property var _rawDb: null

	// Debug/CI hook: SPECTRUM_FORCE=1 starts the capture without a playing player.
	readonly property bool forceRun: Quickshell.env("SPECTRUM_FORCE") === "1"

	readonly property string scriptPath: Quickshell.env("HOME") + "/.config/quickshell/scripts/music-spectrum.py"

	// dB range mapped onto the 0..1 level span.
	readonly property real dbFloor: -55.0
	readonly property real dbCeil: -18.0

	// Per-band sensitivity boost in dB: music carries most of its energy in
	// the lows, so the upper two bars get extra gain (tweak here).
	readonly property var bandGainsDb: [0.0, 0.0, 8.0, 13.0]

	// Sweep rate: 20 fps (animation feel of cava), 10 fps debug mode.
	readonly property int sweepInterval: Quickshell.env("SPECTRUM_LOWFPS") === "1" ? 100 : 50

	// Decay factor per sweep tick, scaled so the release feel stays the same
	// if the sweep rate changes (0.86 at 40 ms ticks).
	readonly property real decayFactor: Math.pow(0.86, sweepInterval / 40.0)

	property bool _logged: false

	// Echoing the old bar behaviour: capture and processing run while music plays.
	Process {
		id: capture

		command: ["/usr/bin/env", "python3", musicSpectrum.scriptPath]
		stdout: SplitParser {
			onRead: function(data) {
				musicSpectrum.pushDb(data);
			}
		}
		running: forceRun || (NowPlaying.hasPlayer && NowPlaying.playing)
	}

	Timer {
		id: sweep

		interval: musicSpectrum.sweepInterval
		repeat: true
		running: forceRun || (NowPlaying.hasPlayer && NowPlaying.playing)
		onTriggered: musicSpectrum.compute()
	}

	Connections {
		target: NowPlaying

		function onPlayingChanged() {
			if (!NowPlaying.playing)
				musicSpectrum.levels = [0, 0, 0, 0];
		}
	}

	// Receive one line of raw band dB values from the capture script.
	function pushDb(line) {
		const parts = line.trim().split(/[\s,]+/);
		if (parts.length < 4)
			return;
		const db = [];
		for (let i = 0; i < 4; i++) {
			const v = Number(parts[i]);
			if (!Number.isFinite(v))
				return;
			db.push(v);
		}
		musicSpectrum._rawDb = db;
	}

	function compute() {
		if (musicSpectrum._rawDb === null)
			return;
		const next = [0, 0, 0, 0];

		for (let b = 0; b < 4; b++) {
			const db = musicSpectrum._rawDb[b] + musicSpectrum.bandGainsDb[b];
			const norm = Math.max(0, Math.min(1, (db - musicSpectrum.dbFloor) / (musicSpectrum.dbCeil - musicSpectrum.dbFloor)));
			// Sharp attack, smooth decay: bars "bounce" like cava.
			next[b] = Math.max(norm, musicSpectrum.levels[b] * musicSpectrum.decayFactor);
		}

		if (!musicSpectrum._logged) {
			musicSpectrum._logged = true;
			console.log("music spectrum bands dB:", musicSpectrum._rawDb.map(v => Math.round(v)).join(" "));
		}
		musicSpectrum.levels = next;
	}
}
