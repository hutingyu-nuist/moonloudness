#!/usr/bin/env python3
"""Differential validation; Python stdlib only, all build/PCM/log scratch in OS temp."""
import argparse
import array
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
RATE = 48000
CASES = [("steady", 8, 1, "mono"), ("gated", 40, 1, "mono"),
         ("stereo", 8, 2, "stereo"), ("surround", 8, 5, "5.0"),
         ("intersample", 8, 1, "mono")]
# Predeclared engineering comparison limits, NOT certification tolerances.
# FFmpeg summary reports tenths: allow its +/-0.05 rounding independently.
TOLERANCES = {"integrated": 0.15, "lra": 0.50, "sp": 0.01, "tp": 0.30}
ROUNDING = 0.05


def checked(command, timeout=300):
    return subprocess.run([str(x) for x in command], cwd=str(ROOT), check=True,
                          stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                          encoding="utf-8", errors="replace", timeout=timeout)


def executable(explicit, name):
    candidate = explicit or shutil.which(name)
    if not candidate or not Path(candidate).is_file():
        raise RuntimeError("Cannot find %s; use --%s with an installed executable" % (name, name))
    return str(Path(candidate).resolve())


def sample(case, frame, channel):
    pi = 3.141592653589793
    phase = 2.0 * pi * (frame % 48) / 48.0
    if case == "steady":
        return 0.1 * math.sin(phase)
    if case == "gated":
        second = frame // RATE
        amplitude = (0.0 if second < 4 else 0.01 if second < 12 else
                     0.1 if second < 20 else 0.001 if second < 28 else
                     0.03 if second < 36 else 0.0)
        return amplitude * math.sin(phase)
    if case == "stereo":
        return (0.1 * math.sin(phase) if channel == 0 else
                0.05 * math.sin(phase + pi / 2.0))
    if case == "surround":
        return 0.1 * math.sin(phase) if channel == 3 else 0.0
    if case == "intersample":
        remaining = 8 * RATE - 1 - frame
        envelope = (frame / 4800.0 if frame < 4800 else
                    remaining / 4800.0 if remaining < 4800 else 1.0)
        return 0.8 * envelope * math.sin(2.0 * pi * (frame % 4) / 4.0 + pi / 4.0)
    raise ValueError(case)


def fixture(directory, case, seconds, channels):
    path = directory / (case + ".f64le")
    energy = total = 0.0
    peak = 0.0
    digest = hashlib.sha256()
    with path.open("wb") as output:
        for start in range(0, seconds * RATE, 997):
            pcm = array.array("d")
            for frame in range(start, min(start + 997, seconds * RATE)):
                for channel in range(channels):
                    x = sample(case, frame, channel)
                    pcm.append(x)
                    total += x
                    energy += x * x
                    peak = max(peak, abs(x))
            if sys.byteorder != "little":
                pcm.byteswap()
            data = pcm.tobytes()
            output.write(data)
            digest.update(data)
    return path, {"energy": energy, "sum": total, "sha256": digest.hexdigest(),
                  "frames": seconds * RATE, "channels": channels,
                  "sp": 20.0 * math.log10(peak)}


NUMBER = r"[-+]?(?:\d+(?:\.\d*)?|inf)"


def parse_summary(log):
    if "Summary:" not in log:
        raise ValueError("FFmpeg did not emit an ebur128 summary")
    text = log.rsplit("Summary:", 1)[1]
    result = {}
    for key, label in [("integrated", "I"), ("lra", "LRA")]:
        match = re.search(r"\b" + label + r":\s*(" + NUMBER + r")", text)
        if not match:
            raise ValueError("Missing FFmpeg " + label)
        result[key] = float(match.group(1))
    for key, section in [("sp", "Sample peak"), ("tp", "True peak")]:
        match = re.search(section + r":\s*Peak:\s*([^\r\n]+)", text)
        if not match:
            raise ValueError("Missing FFmpeg " + section)
        values = re.findall(NUMBER, match.group(1).split("dB", 1)[0])
        if not values:
            raise ValueError("Empty FFmpeg " + section)
        result[key] = max(float(value) for value in values)
    if not all(math.isfinite(value) for value in result.values()):
        raise ValueError("Non-finite reference result for a non-silent fixture")
    return result


def parse_moon(text):
    rows = [json.loads(line) for line in text.splitlines() if line.startswith('{')]
    ids = [row.get("id") for row in rows]
    if ids != [case[0] for case in CASES]:
        raise ValueError("Unexpected/duplicate/missing MoonBit cases: " + repr(ids))
    return {row["id"]: row for row in rows}


def compare(value, reference, key):
    if value is None or not math.isfinite(value):
        return False
    return abs(value - reference) <= TOLERANCES[key] + ROUNDING + 1e-9


def run(args):
    moon = executable(args.moon, "moon")
    ffmpeg = executable(args.ffmpeg, "ffmpeg")
    moon_version = checked([moon, "version"]).stdout.strip()
    ffmpeg_version = checked([ffmpeg, "-version"]).stdout.splitlines()[0]
    timestamp = datetime.datetime.now(datetime.timezone.utc).isoformat()
    lines = ["# FFmpeg ebur128 differential measurement", "", "- UTC run: " + timestamp,
             "- Platform: " + platform.platform(), "- Python: " + sys.version.replace("\n", " "),
             "- Moon executable: `" + moon + "`", "- Moon version: `" + moon_version.replace("\n", " / ") + "`",
             "- FFmpeg executable: `" + ffmpeg + "`", "- FFmpeg version: `" + ffmpeg_version + "`",
             "- Mode: release; all scratch files/build products in an OS TemporaryDirectory (deleted on exit).",
             "- Input: independently synthesized IEEE float64 little-endian PCM, 48 kHz; no decoder/downmix.",
             "- FFmpeg: `-nostdin -hide_banner -nostats -loglevel info -threads 1 -f f64le -ar 48000 "
             "-ch_layout LAYOUT -i PCM -af ebur128=peak=sample+true -f null -`", "",
             "Limits are engineering regression limits, not certified conformance. Absolute deltas use unrounded "
             "MoonBit values and FFmpeg summary tenths. Add 0.05 for FFmpeg rounding to the predeclared limits "
             "I=0.15 LU, LRA=0.50 LU, SP=0.01 dB, TP=0.30 dB. Table display rounds to 4 decimals only.", "",
             "| Target | Case | Metric | MoonBit | FFmpeg | absolute delta | allowed | Result |",
             "|---|---|---|---:|---:|---:|---:|---|"]
    failures = []
    with tempfile.TemporaryDirectory(prefix="moonloudness-reference-") as scratch:
        directory = Path(scratch).resolve()
        if directory == ROOT or ROOT in directory.parents:
            raise RuntimeError("Temporary directory must be outside repository; change TMP/TEMP/TMPDIR")
        fixtures = {}
        references = {}
        for case, seconds, channels, layout in CASES:
            pcm, metadata = fixture(directory, case, seconds, channels)
            fixtures[case] = metadata
            command = [ffmpeg, "-nostdin", "-hide_banner", "-nostats", "-loglevel", "info", "-threads", "1",
                       "-f", "f64le", "-ar", str(RATE), "-ch_layout", layout, "-i", pcm,
                       "-af", "ebur128=peak=sample+true", "-f", "null", "-"]
            result = checked(command)
            (directory / (case + "-ffmpeg.log")).write_text(result.stderr, encoding="utf-8")
            references[case] = parse_summary(result.stderr)
        for target in args.targets:
            result = checked([moon, "run", "examples/reference", "--target", target, "--release",
                              "--deny-warn", "--target-dir", directory / ("build-" + target)])
            measurements = parse_moon(result.stdout)
            for case, seconds, channels, layout in CASES:
                measured, metadata = measurements[case], fixtures[case]
                # Energy/sum parity detects independently generated fixture drift before comparing meters.
                for key in ("frames", "channels", "sum", "energy"):
                    if not math.isclose(measured[key], metadata[key], rel_tol=1e-10, abs_tol=1e-9):
                        raise ValueError("Fixture parity failure %s/%s/%s" % (target, case, key))
                if not math.isclose(measured["sp"], metadata["sp"], abs_tol=1e-9):
                    raise ValueError("Sample peak fixture parity failure " + case)
                for key in TOLERANCES:
                    value, ref = measured[key], references[case][key]
                    passed = compare(value, ref, key)
                    if not passed:
                        failures.append("%s/%s/%s" % (target, case, key))
                    delta = "n/a" if value is None else "%.4f" % abs(value - ref)
                    shown = "unavailable" if value is None else "%.4f" % value
                    lines.append("| %s | %s | %s | %s | %.4f | %s | %.2f | %s |" %
                                 (target, case, key, shown, ref, delta, TOLERANCES[key] + ROUNDING,
                                  "PASS" if passed else "FAIL"))
        lines += ["", "## Fixture provenance and parity", "",
                  "Formulas are maintained in `examples/reference/main.mbt` and independently in "
                  "`tools/validate_reference.py`. Every target checks frame/channel counts, sample sum, "
                  "squared-energy sum (1e-10 relative, 1e-9 absolute), and sample peak (1e-9 dB) before "
                  "meter comparisons. This is a drift guard, not a proof of bit-identical PCM.", "",
                  "| Case | seconds | channels/layout | SHA256 of Python f64le input |",
                  "|---|---:|---|---|"]
        for case, seconds, channels, layout in CASES:
            lines.append("| %s | %d | %d / %s | `%s` |" %
                         (case, seconds, channels, layout, fixtures[case]["sha256"]))
    lines += ["", "## Outcome", "", "%d metric comparisons; %d outside limits." %
              (len(args.targets) * len(CASES) * len(TOLERANCES), len(failures))]
    if failures:
        lines += ["", "Failures: " + ", ".join(failures), "",
                  "A nonzero exit is intentional: investigate algorithm/window/gate/interpolation differences; "
                  "do not relabel failures as agreement or silently increase tolerances."]
    else:
        lines += ["", "Agreement on these generated cases does not establish full EBU/ITU compliance or certification."]
    report = "\n".join(lines) + "\n"
    if args.report:
        Path(args.report).write_text(report, encoding="utf-8")
    print(report)
    return 1 if failures else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--moon", help="Installed moon executable (default: PATH)")
    parser.add_argument("--ffmpeg", help="Installed ffmpeg executable (default: PATH)")
    parser.add_argument("--targets", nargs="+", choices=["wasm", "wasm-gc", "js"],
                        default=["wasm", "wasm-gc", "js"])
    parser.add_argument("--report", help="Explicit persistent Markdown output; otherwise stdout only")
    args = parser.parse_args()
    try:
        return run(args)
    except subprocess.CalledProcessError as error:
        print("Checked subprocess failed: %r\n%s\n%s" % (error.cmd, error.stdout, error.stderr), file=sys.stderr)
        return 2
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("Validation could not complete: " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
