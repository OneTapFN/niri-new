#!/usr/bin/env python3
# Сэмпл-поток для визуализатора музыки на панели quickshell.
#
# Reads the default audio OUT through pw-record with stream.capture.sink=true
# (mirrors PulseAudio's monitor=1) and computes raw dB levels for the four
# frequency bands with a numpy FFT (numpy installs cleanly without sudo).
# One "db0 db1 db2 db3" line is printed per ~33 ms frame; the QML side only
# applies gains, normalisation and decay smoothing.
#
# Usage: music-spectrum.py            # real capture from the default sink
#        music-spectrum.py -t         # test mode, reads PCM from stdin
#
# stdin format for -t: raw f32le mono @ 48000 Hz.
import json
import os
import re
import signal
import subprocess
import sys

import numpy as np

RATE = 48000          # pw-record capture rate
FRAME = 1600          # samples per output frame (~33 ms @ 48 kHz)

BANDS = [(50, 220), (220, 900), (900, 3000), (3000, 5900)]

WINDOW = np.hanning(FRAME)
BINS = np.arange(FRAME // 2 + 1)
BIN_HZ = RATE / FRAME
# Bin index ranges for each band, fixed at import time.
SEL = [((BINS >= max(1, round(lo / BIN_HZ))) & (BINS <= min(len(BINS) - 1, round(hi / BIN_HZ)))) for lo, hi in BANDS]


def convert(frame):
	# f32 little-endian samples -> band dB list. NaN from the capture layer
	# is replaced with silence before the transform.
	samples = np.frombuffer(frame, dtype="<f4").astype(np.float64)
	np.nan_to_num(samples, copy=False, nan=0.0)
	mag2 = np.abs(np.fft.rfft(samples * WINDOW)) ** 2
	out = []
	for sel in SEL:
		count = int(sel.sum())
		# RMS of the bin magnitudes, Hann gain 0.5 restored *4/N.
		amp = 4.0 * np.sqrt(mag2[sel].sum() / max(1, count)) / FRAME
		out.append(20 * np.log10(amp + 1e-9) if amp > 0 else -180.0)
	return out


def default_sink():
	# pw-dump hides the metadata contents on this install, pw-metadata does not.
	try:
		out = subprocess.run(["pw-metadata"], capture_output=True, text=True, timeout=5).stdout
	except Exception:
		return ""
	sink = ""
	for line in out.splitlines():
		m = re.search(r"key:'([^']+)' value:'([^']*)'", line)
		if not m or "sink" not in m.group(1):
			continue
		try:
			name = json.loads(m.group(2)).get("name", "")
		except Exception:
			continue
		key = m.group(1)
		if key == "default.audio.sink":
			sink = name
			break
		if key == "default.configured.audio.sink" and name:
			sink = name
	# A direct .monitor node does not exist for bluez sinks, but
	# stream.capture.sink=true routes the stream in every case.
	return sink


def main(argv):
	if "-t" in argv:
		stream = sys.stdin.buffer
		proc = None
	else:
		sink = default_sink()
		if not sink:
			print("music-spectrum: no default sink found", file=sys.stderr)
			return
		proc = subprocess.Popen(
			["pw-record", "-P", "stream.capture.sink=true", "--raw",
			 "--format=f32", "--rate=%d" % RATE, "--channels=1",
			 "--latency=40ms", "--target", sink, "-"],
			stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
		stream = proc.stdout

	running = True

	def stop(*_):
		nonlocal running
		running = False

	signal.signal(signal.SIGTERM, stop)

	need = FRAME * 4  # f32 bytes per frame
	buffer = b""
	frame_count = 0
	# Debug metrics only with SPECTRUM_FORCE=1 in the environment.
	debug_log = None
	if os.environ.get("SPECTRUM_FORCE"):
		try:
			debug_log = open("/tmp/opencode/spectrum-debug.log", "w")
		except Exception:
			pass
	try:
		while running:
			block = stream.read(need - len(buffer))
			if not block:
				break
			buffer += block
			while len(buffer) >= need and running:
				frame, buffer = buffer[:need], buffer[need:]
				db = convert(frame)
				frame_count += 1
				if frame_count % 30 == 0 and debug_log:
					debug_log.write("frame %d db=%s\n" % (
						frame_count, " ".join(format(v, ".1f") for v in db)))
					debug_log.flush()
				sys.stdout.write(" ".join(format(v, ".1f") for v in db) + "\n")
				sys.stdout.flush()
	except KeyboardInterrupt:
		pass
	finally:
		if proc:
			proc.terminate()
			proc.wait()


if __name__ == "__main__":
	main(sys.argv[1:])
