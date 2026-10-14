# Independent-program QC and measured throughput

## Repeat

```sh
moon run examples/batch --target wasm-gc --release
python tools/test_measure_batch.py
python tools/measure_batch.py
python tools/measure_batch.py --report docs/validation/batch-results.md
python tools/measure_batch.py --targets js --warmups 1 --repetitions 5
```

Requirements: Python 3.8+ standard library, MoonBit, `node` for JS and `moonrun`
for Wasm. The harness discovers installed executables on PATH; `--moon`,
`--node`, and `--moonrun` override lookup. No FFmpeg is required for this workflow.
All builds live in an automatically cleaned OS TemporaryDirectory outside the
checkout. Normal output is stdout; `--report` is an intentional persistent
Markdown result. Exit 0 means the checked workloads and QC assertions completed;
exit 2 means a subprocess/infrastructure/output/correctness guard failed. Each
subprocess is checked with a 300 s watchdog. Invalid iteration counts are rejected.

## What the example does

Four *independent* 8 s, 48 kHz programs use fresh `Analyzer` instances, then
add their finished public `MeasurementReport`s to `LoudnessAggregator`. An
original 1 kHz sine uses 4800-frame (100 ms) reusable blocks with integer phase
reduction, fed 80 times. No retained PCM is needed by the aggregate. The workload
has 1,536,000 frames and 1,920,000 channel samples because one asset is stereo.

| Program | Layout / amplitude | Illustrative per-program QC on this fixture |
|---|---|---|
| on_target | mono / .1 | loudness pass, true-peak pass |
| quiet_stereo | stereo, same tone in both channels / .05 | loudness fail, true-peak pass |
| hot | mono / .95 | loudness fail, true-peak fail |
| silence | mono / 0 | unavailable loudness/peaks, not a passing delivery |

The example policy is integrated -23 +/-2 LU and TP <= -1 dBTP, not a universal
broadcasting requirement. It emits JSON with I/LRA/SP/TP and separate policy
booleans per asset, followed by the aggregate. These intended QC failures are
not runtime failures. They must not be suppressed by the batch summary.

The aggregate pools distributions of already independent measurements and
preserves maximum peaks; it is **not** a LUFS average or a continuous concatenated
stream. It does not add invented windows across asset boundaries. On these
assets, the integrated relative gate retains the hot asset alone; the pooled LRA
is about 22.57 LU despite every individual non-silent program having zero LRA.
A pooled normalization plan would not be a substitute for per-program delivery QC.

## Timing and correctness guards

`measure_batch.py` performs a release build outside the timer and launches the
actual artifact directly using Node (`batch.js`) or moonrun (`batch.wasm`). It
checks that exactly one matching artifact was built. The default is one untimed
launch, then five timed **fresh-process** launches for each portable target in
`wasm`, `wasm-gc`, `js` order. The `time.perf_counter()` interval covers process
startup, runtime/JIT startup, block generation, analyzer creation, push/finish,
aggregation, printing and captured pipes. Parsing/checks and Moon compilation
are excluded. Reusing the periodic input block avoids benchmark domination by
millions of trigonometric calls while still feeding every counted sample through
the public library. This is not an isolated DSP-loop or steady-state JIT test.

Each launch validates asset IDs/counts/frame counts/channels, finite metrics,
explicit unavailable silence metrics, expected QC outcomes, aggregate duration,
maximum peaks, integrated gating and pooled LRA. All timed values agree across
launches/targets within absolute 1e-8 (default relative tolerance 1e-9). Unit
tests also force invalid workloads, missing results, wrong QC, non-finite data,
and incorrect pooled statistics to fail; their synthetic JSON is not reported
as a measurement. The report includes every observed timing, min/median/max,
frames/s, channel samples/s and audio-duration/wall-time ratio computed from
verified counts, along with runtime versions, processor description and a
production/example source fingerprint.

## Actual local observations

`batch-results.md` records the 2026-10-14 Windows run with Moon 0.1.20260920,
moonrun 0.1.20260920 and Node v24.14.0. See that report for all raw timings and
median-derived rates. All four individual policy outcomes and independent
aggregation guards passed on every run. The hot program/aggregate integrated
loudness was -3.4491 LUFS, TP -0.4388 dBTP; aggregate LRA was 22.57 LU.

The full module passed `moon check --deny-warn` and `moon test --deny-warn` on
`wasm`, `wasm-gc`, and `js` after adding this example; each target passed all 20
library tests. The batch harness has six passing Python self-tests, separate
from the eight reference harness tests. `moon info examples/batch` then
`moon fmt examples/batch` succeeded, with no library interface modification.

These are machine-specific foreground wall-clock observations, not fabricated
capacity figures. CPU load, clock scaling, OS scheduling, target order and
fresh-process startup all affect them. No isolation/affinity or frequency
control was applied. Do not infer a production SLA, latency percentile,
real-time scheduling guarantee, concurrency scalability, certification, or a
benchmark of arbitrary decoded audio from this synthetic batch.
