pragma Singleton

import QtQuick
import Quickshell

// Weather in Pavlovsky Posad from the free met.no Locationforecast API
// (no key required, an identifying User-Agent is mandatory).
Singleton {
	id: weather

	// Pavlovsky Posad: 55.7784 N, 38.6536 E.
	readonly property string apiUrl:
		"https://api.met.no/weatherapi/locationforecast/2.0/compact?lat=55.7784&lon=38.6536"

	// --- state -----------------------------------------------------------
	property bool loading: false
	property bool ready: false
	property bool failed: false
	property real temp: NaN
	property string symbol: ""
	property var lastFetch: null

	// Next 12 hours for the dropdown menu: {time, temp, symbol, precip}.
	property var hourly: []
	// Days ahead for the dropdown menu: {time, min, max, symbol, precip}.
	property var daily: []

	// Signed rounded degrees, "—" until the first successful fetch.
	readonly property string tempText: ready ? fmtTemp(temp) : "\u2014"

	// Short condition description in Russian from the met.no symbol code.
	readonly property string description: ready ? describe(symbol) : ""

	// Condition line for the bar pill, falls back to connection status.
	readonly property string subtitle: {
		if (ready)
			return describe(symbol);
		if (loading)
			return "Загрузка…";
		return failed ? "Нет сети" : "";
	}

	// FontAwesome weather glyph from the met.no symbol code; _night suffix
	// switches sun and moon.
	readonly property string glyph: {
		if (failed && !ready)
			return Theme.icoWeatherQuestion;
		if (!ready)
			return Theme.icoWeatherCloud;
		return glyphFor(symbol);
	}

	// Russian weekday names, met.no times are Date objects in local time.
	readonly property var dayNames: ["Вс", "Пн", "Вт", "Ср", "Чт", "Пт", "Сб"]

	Timer {
		id: refresher
		interval: 30 * 60 * 1000
		repeat: true
		running: true
		onTriggered: weather.refresh()
	}

	Component.onCompleted: refresh()

	// --- functions -------------------------------------------------------
	function refresh() {
		if (loading)
			return;
		const now = new Date();
		if (lastFetch && now.getTime() - lastFetch.getTime() < 15000)
			return;
		loading = true;

		const request = new XMLHttpRequest();
		request.open("GET", apiUrl);
		// met.no requires an identifying User-Agent.
		request.setRequestHeader("User-Agent", "onetap-panel/1.0 (quickshell weather pill)");
		request.onreadystatechange = function() {
			if (request.readyState !== XMLHttpRequest.DONE)
				return;
			loading = false;
			lastFetch = new Date();
			if (request.status !== 200) {
				// Keep showing the previous data if the fetch failed.
				failed = true;
				return;
			}
			try {
				const data = JSON.parse(request.responseText);
				const steps = data.properties.timeseries ?? [];
				if (steps.length === 0) {
					failed = true;
					return;
				}
				const parsed = parseForecast(steps);
				if (Number.isFinite(parsed.temp)) {
					temp = parsed.temp;
					symbol = parsed.symbol;
					hourly = parsed.hourly;
					daily = parsed.daily;
					ready = true;
					failed = false;
				} else {
					failed = true;
				}
			} catch (e) {
				failed = true;
			}
		};
		request.send();
	}

	// Turns the raw met.no timeseries into menu data: up to 12 hour steps
	// (only steps carrying next_1_hours) and day aggregates (min/max temps,
	// midday symbol and total precipitation) for the next 7 days.
	function parseForecast(steps) {
		const hourSteps = [];
		const dayMap = {};
		for (let i = 0; i < steps.length; i++) {
			const step = steps[i];
			const when = new Date(step.time);
			const tempNow = step.data.instant.details.air_temperature;
			const buckets = step.data.next_1_hours ?? step.data.next_6_hours ?? null;
			const symbolNow = buckets ? (buckets.summary?.symbol_code ?? "") : "";
			const precipNow = buckets ? (buckets.details?.precipitation_amount ?? 0) : 0;

			if (step.data.next_1_hours && hourSteps.length < 12)
				hourSteps.push({ time: when, temp: tempNow, symbol: symbolNow, precip: precipNow });

			const dayKey = Qt.formatDateTime(when, "yyyy-MM-dd");
			const day = dayMap[dayKey] ?? null;
			if (day) {
				if (tempNow < day.min)
					day.min = tempNow;
				if (tempNow > day.max)
					day.max = tempNow;
				day.precip += precipNow;
			} else {
				dayMap[dayKey] = { time: when, min: tempNow, max: tempNow, symbol: symbolNow, precip: precipNow };
			}
			// Day symbol: the code closest to the middle of the local day.
			if (day && when.getHours() >= 11 && when.getHours() <= 17 && symbolNow !== "")
				day.symbol = symbolNow;
		}

		const days = [];
		for (const key in dayMap) {
			const day = dayMap[key];
			if (Number.isFinite(day.min) && Number.isFinite(day.max))
				days.push(day);
		}
		days.sort((a, b) => a.time.getTime() - b.time.getTime());
		return {
			temp: steps[0].data.instant.details.air_temperature,
			symbol: (steps[0].data.next_1_hours ?? steps[0].data.next_6_hours ?? null)?.summary?.symbol_code ?? "",
			hourly: hourSteps,
			daily: days.slice(0, 7)
		};
	}

	function fmtTemp(value) {
		if (!Number.isFinite(value))
			return "\u2014";
		const v = Math.round(value);
		return (v > 0 ? "+" : "") + v + "\u00b0";
	}

	// Millimetres shown as 0.3 / 12; empty string for traceless conditions.
	function fmtPrecip(value) {
		if (!Number.isFinite(value) || value < 0.1)
			return "";
		return value >= 10 ? "" + Math.round(value) : value.toFixed(1);
	}

	function describe(symbol) {
		const word = symbol.split("_")[0];

		// Thunder wins over everything else, rain and snow may both be present.
		if (word.includes("thunder"))
			return "Гроза";
		switch (word) {
			case "clearsky": return "Ясно";
			case "fair": return "Почти ясно";
			case "partlycloudy": return "Облачно с прояснениями";
			case "cloudy": return "Пасмурно";
			case "fog": return "Туман";
			case "rainshowers": return intensity(word) + " ливень";
			case "rain": return intensity(word) + " дождь";
			case "sleetshowers": return intensity(word) + " мокрый снег с ливнями";
			case "sleet": return intensity(word) + " мокрый снег";
			case "snowshowers": return intensity(word) + " снежный ливень";
			case "snow": return intensity(word) + " снег";
			default: return "";
		}
	}

	// "light" / "heavy" intensity prefix of the symbol code.
	function intensity(word) {
		if (word.startsWith("heavy"))
			return "Сильный";
		if (word.startsWith("light"))
			return "Небольшой";
		return "";
	}

	function glyphFor(symbol) {
		const word = symbol.split("_")[0];
		if (word.includes("thunder"))
			return Theme.icoWeatherThunder;
		if (word.includes("snow") || word.includes("sleet"))
			return Theme.icoWeatherSnow;
		switch (word) {
			case "clearsky":
			case "fair":
				return symbol.endsWith("_night") ? Theme.icoWeatherMoon : Theme.icoWeatherSun;
			case "partlycloudy":
			case "cloudy":
			case "fog":
				return Theme.icoWeatherCloud;
			default:
				if (word.includes("rain"))
					return Theme.icoWeatherRain;
				return Theme.icoWeatherCloud;
		}
	}
}
