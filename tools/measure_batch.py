#!/usr/bin/env python3
"""Fresh-process throughput of the independent-program QC/aggregation example."""
import argparse
import datetime
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import statistics
import subprocess
import sys
import tempfile
import time

sys.dont_write_bytecode = True
from validate_reference import ROOT, checked, executable

IDS = ["on_target", "quiet_stereo", "hot", "silence"]
FRAMES = 4 * 8 * 48000
SAMPLES = 5 * 8 * 48000  # One stereo asset plus three mono assets.
AUDIO_SECONDS = 32.0


def validate_output(text):
    rows = [json.loads(line) for line in text.splitlines() if line.startswith('{')]
    if len(rows) != 5 or [row.get("id") for row in rows[:-1]] != IDS:
        raise ValueError("Missing/duplicate/unexpected independently measured programs")
    expected_qc = [(True, True), (False, True), (False, False), (False, False)]
    for row, channels, qc in zip(rows[:-1], [1, 2, 1, 1], expected_qc):
        if row.get("kind") != "program" or row.get("frames") != 8 * 48000 or row.get("channels") != channels:
            raise ValueError("Wrong program workload")
        if (row.get("loudness_ok"), row.get("peak_ok")) != qc:
            raise ValueError("Unexpected per-program QC result: " + row["id"])
        if row["id"] == "silence":
            if any(row.get(key) is not None for key in ["integrated", "lra", "sp", "tp"]):
                raise ValueError("Silent asset must be unavailable, not a finite invented loudness")
        elif not all(row.get(key) is not None and math.isfinite(row[key]) for key in ["integrated", "lra", "sp", "tp"]):
            raise ValueError("Non-finite program measurement")
    batch = rows[-1]
    if batch.get("kind") != "aggregate" or batch.get("assets") != 4 or batch.get("frames") != FRAMES or batch.get("duration") != AUDIO_SECONDS:
        raise ValueError("Wrong aggregate workload")
    if not all(batch.get(key) is not None and math.isfinite(batch[key]) for key in ["integrated", "lra", "sp", "tp"]):
        raise ValueError("Non-finite aggregate measurement")
    for key in ["sp", "tp"]:
        maximum = max(row[key] for row in rows[:-1] if row[key] is not None)
        if not math.isclose(batch[key], maximum, abs_tol=1e-9):
            raise ValueError("Aggregate must preserve maximum independent-program " + key)
    # On this fixture, the integrated relative gate excludes the two quiet
    # assets. Averaging their LUFS would give a completely different result.
    if not math.isclose(batch["integrated"], rows[2]["integrated"], rel_tol=0.0, abs_tol=1e-6):
        raise ValueError("Pooled integrated gating must retain only the hot program on this fixture")
    if not 20.0 < batch["lra"] < 24.0:
        raise ValueError("Pooled LRA must reflect between-program levels, not average per-program LRA")
    return rows


def source_digest():
    digest = hashlib.sha256()
    sources = [p for p in ROOT.glob("*.mbt") if not p.name.endswith(("_test.mbt", "_wbtest.mbt"))]
    sources += [ROOT / "moon.mod", ROOT / "moon.pkg", ROOT / "examples/batch/main.mbt", ROOT / "examples/batch/moon.pkg"]
    for path in sorted(sources):
        digest.update(path.relative_to(ROOT).as_posix().encode("utf-8") + b"\0")
        # Normalize line endings, making this source identity stable across Git checkouts.
        digest.update(path.read_bytes().replace(b"\r\n", b"\n") + b"\0")
    return digest.hexdigest()


def run(args):
    moon = executable(args.moon, "moon")
    node = executable(args.node, "node") if "js" in args.targets else None
    moonrun = executable(args.moonrun, "moonrun") if any(target != "js" for target in args.targets) else None
    lines = ["# Independent-program batch throughput", "",
             "- UTC run: " + datetime.datetime.now(datetime.timezone.utc).isoformat(),
             "- Platform: " + platform.platform(), "- Processor: " + platform.processor(),
             "- Logical CPUs reported by OS: " + str(os.cpu_count()),
             "- Python timer/controller: " + sys.version.replace("\n", " "),
             "- Moon: `" + moon + "`; `" + checked([moon, "version"]).stdout.strip().replace("\n", " / ") + "`",
             "- Production and batch source SHA256 (sorted path-NUL/content-NUL, LF normalized): `" + source_digest() + "`"]
    if node:
        lines.append("- JS runtime: `" + node + "`; `" + checked([node, "--version"]).stdout.strip() + "`")
    if moonrun:
        lines.append("- Wasm runtime: `" + moonrun + "`; `" + checked([moonrun, "--version"]).stdout.strip() + "`")
    lines += ["", "## Timing definition", "",
              "Build release artifacts once outside the repository. Launch each artifact directly with Node or moonrun; "
              "compilation by moon is excluded. Each invocation measures four fresh independent 8 s programs "
              "(32 s audio, 1,536,000 frames, 1,920,000 interleaved channel samples). It includes PCM-block "
              "generation, analyzer creation/push/finish (K weighting, gating, LRA, SP, TP), independent-program "
              "aggregation, JSON printing, process startup, runtime/JIT initialization and pipe capture. "
              "Validation parsing is outside the timer. It is not an isolated DSP-loop benchmark.", "",
              "%d untimed fresh-process warmup(s) then %d timed fresh-process launches per target. "
              "Warmup warms OS/cache state, not persistent-process JIT. Target order: %s. "
              "No CPU isolation, affinity, frequency control, or guarantees for other machines." %
              (args.warmups, args.repetitions, ", ".join(args.targets)), "",
              "| Target | wall seconds (all timed runs) | median s | min s | max s | frames/s at median | channel samples/s at median | audio seconds / wall second |",
              "|---|---|---:|---:|---:|---:|---:|---:|"]
    representative = None
    with tempfile.TemporaryDirectory(prefix="moonloudness-throughput-") as scratch:
        directory = Path(scratch).resolve()
        if ROOT == directory or ROOT in directory.parents:
            raise RuntimeError("OS temporary directory must be outside repository")
        for target in args.targets:
            build = directory / target
            checked([moon, "build", "examples/batch", "--target", target, "--release", "--deny-warn", "--target-dir", build])
            suffix = ".js" if target == "js" else ".wasm"
            artifacts = [path for path in build.rglob("batch" + suffix) if path.is_file()]
            if len(artifacts) != 1:
                raise RuntimeError("Expected one release batch artifact, found: " + repr(artifacts))
            command = [node if target == "js" else moonrun, artifacts[0]]
            for _ in range(args.warmups):
                validate_output(checked(command).stdout)
            times = []
            for _ in range(args.repetitions):
                start = time.perf_counter()
                output = checked(command)
                elapsed = time.perf_counter() - start
                rows = validate_output(output.stdout)
                if elapsed <= 0.0:
                    raise RuntimeError("Timer failed to advance")
                if representative is None:
                    representative = rows
                # Cross-target/launch determinism without requiring identical final libm bits.
                for reference_row, row in zip(representative, rows):
                    for key in ["integrated", "lra", "sp", "tp"]:
                        x, y = reference_row[key], row[key]
                        if (x is None) != (y is None) or (x is not None and not math.isclose(x, y, abs_tol=1e-8)):
                            raise ValueError("Measurement changed across launch/target: " + key)
                times.append(elapsed)
            median = statistics.median(times)
            lines.append("| %s | %s | %.6f | %.6f | %.6f | %.0f | %.0f | %.2fx |" %
                         (target, ", ".join("%.6f" % value for value in times), median,
                          min(times), max(times), FRAMES / median, SAMPLES / median, AUDIO_SECONDS / median))
    lines += ["", "## Verified QC output", "",
              "Every timed and warmup launch is checked for all four program IDs, frames/channels, finite metrics "
              "(except silence), the expected per-program QC decisions, and aggregate counters/max peaks and pooled gate/LRA behavior. "
              "These expected failing QC decisions demonstrate policy handling; they are not execution failures. "
              "All timed launches also agree in measured values across targets (absolute 1e-8 with Python "
              "math.isclose default relative 1e-9).", "", "```json"]
    lines += [json.dumps(row, sort_keys=True) for row in representative]
    lines += ["```", "", "The illustrative per-program policy is -23 +/-2 LU integrated and TP <= -1 dBTP. "
              "Aggregate I/LRA comes from pooled independent-program distributions, not average LUFS and "
              "not a concatenated stream with cross-program windows. An aggregate passing any policy cannot "
              "override a failing individual program. No certification, production SLA or real-time scheduling claim.", ""]
    report = "\n".join(lines)
    if args.report:
        Path(args.report).write_text(report, encoding="utf-8")
    print(report)
    return 0


def positive(value):
    integer = int(value)
    if integer < 1:
        raise argparse.ArgumentTypeError("must be >= 1")
    return integer


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ["moon", "node", "moonrun"]:
        parser.add_argument("--" + name, help="Explicit installed " + name + " executable; default PATH")
    parser.add_argument("--targets", nargs="+", choices=["wasm", "wasm-gc", "js"], default=["wasm", "wasm-gc", "js"])
    parser.add_argument("--repetitions", type=positive, default=5)
    parser.add_argument("--warmups", type=positive, default=1)
    parser.add_argument("--report", help="Explicit persistent Markdown report; otherwise stdout only")
    args = parser.parse_args()
    try:
        return run(args)
    except subprocess.CalledProcessError as error:
        print("Checked subprocess failed: %r\n%s\n%s" % (error.cmd, error.stdout, error.stderr), file=sys.stderr)
        return 2
    except (OSError, ValueError, RuntimeError, subprocess.TimeoutExpired) as error:
        print("Throughput measurement could not complete: " + str(error), file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
