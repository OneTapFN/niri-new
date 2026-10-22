pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

// Currently active MPRIS player shared by the bar and the media popup.
// Prefer a player that is actually playing, then any player with a track.
Singleton {
	id: nowPlaying

	readonly property var player: {
		const players = Mpris.players.values;
		for (let i = 0; i < players.length; i++) {
			const candidate = players[i];
			if (candidate.isPlaying && candidate.trackTitle !== "")
				return candidate;
		}
		for (let i = 0; i < players.length; i++) {
			const candidate = players[i];
			if (candidate.playbackState !== MprisPlaybackState.Stopped && candidate.trackTitle !== "")
				return candidate;
		}
		return null;
	}

	readonly property bool hasPlayer: player !== null
	readonly property string title: player ? player.trackTitle : ""
	readonly property string artist: player ? player.trackArtist : ""
	readonly property string album: player ? player.trackAlbum : ""
	readonly property string artUrl: player ? player.trackArtUrl : ""
	readonly property string appName: {
		if (!player)
			return "";
		return player.identity || player.desktopEntry || "Media";
	}
	readonly property string appIcon: {
		if (!player)
			return Quickshell.iconPath("", "application-x-executable");
		return Quickshell.iconPath(player.desktopEntry, "application-x-executable");
	}
	readonly property bool playing: player ? player.isPlaying : false
	readonly property real position: player ? player.position : 0
	readonly property real length: player ? player.length : 0
}
