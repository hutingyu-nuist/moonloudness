# MoonLoudness

MoonLoudness is a pure MoonBit library for streaming loudness and peak analysis of interleaved PCM. It provides an in-process measurement core for quality-control pipelines, batch media tools, live meters, and audio engineering applications.

## Install

Module identity: **hutingyu-nuist/moonloudness@0.1.0**. Check exact-version public registry metadata for availability; a package build alone is not proof of publication. Source checkout is usable independently:

```sh
git clone https://github.com/hutingyu-nuist/moonloudness.git
cd moonloudness
moon check --target wasm-gc
moon test --target wasm-gc
```

For an available published version, downstream projects can add `hutingyu-nuist/moonloudness` with `moon add hutingyu-nuist/moonloudness`. Verify the resolved manifest version before relying on it. No MoonCakes credential is needed to consume a public package.

## Supported measurement path

- 48,000 Hz PCM samples in interleaved frames; mono (`C`), stereo (`L,R`), and 5.0 (`L,R,C,Ls,Rs`, without LFE).
- Per-channel K-weighting, 400 ms momentary and 3 s short-term windows, integrated loudness gating, short-term loudness range (LRA), sample peaks, and four-phase true-peak estimates.
- Whole-chunk input validation before mutation. Incomplete frames, non-finite values, and magnitudes above `1e150` are rejected.
- Bounded measurement history (600 points by default; configurable from 0 to 100,000) and fixed-memory aggregation of finalized independent program reports.
- Auditable gate thresholds/block counts, explicit `GateStatus` availability, detached versioned JSON, and a non-destructive constant-gain recommendation constrained by a caller-provided true-peak ceiling.
- Synchronous zero-copy `push_view`, checked independent-group merging and stable history/reset contracts.

The implementation uses 0.01 LU histogram buckets for bounded-memory gate/percentile storage. Gate thresholds are conservatively quantized to bucket edges; this is not an exact arbitrary-duration block archive. The project does not claim ITU-R BS.1770-5 or EBU Tech 3341/3342/3343 conformance, and the EBU official test suite has not been run.

## Quick start

```moonbit
let layout = @moonloudness.ChannelLayout::mono()
let config = match @moonloudness.MeterConfig::new(48000, layout) {
  Ok(value) => value
  Err(_) => panic()
}
let meter = @moonloudness.Analyzer::new(config)
match meter.push(samples) { // Array[Double], complete interleaved frames
  Ok(_) => ()
  Err(_) => panic()
}
let report = meter.finish()
match report.integrated_lufs() {
  Some(value) => println(value.to_string())
  None => println("Integrated loudness unavailable")
}
match report.true_peak_dbtp() {
  Some(value) => println(value.to_string())
  None => println("True peak unavailable")
}
```

`Analyzer::push` accepts normalized floating-point samples and keeps finite values outside `[-1,1]` for headroom analysis, up to the documented numeric bound. No decoder, container reader, resampler, playback engine, limiter, or automatic gain application is included.

## Examples

Each example is executable from the module root:

```sh
moon run examples/mono --target wasm-gc
moon run examples/stereo --target wasm-gc
moon run examples/surround --target wasm-gc
moon run examples/batch --target wasm-gc
moon run examples/reference --target wasm-gc
```

- `mono`: analyze a 1 kHz program and inspect an advisory gain plan.
- `stereo`: feed bounded chunks and inspect the retained time series and gate trace.
- `surround`: inspect channel labels/weights and channel-ordered peak measurements for a 5.0 signal.

## Build and test

```sh
moon info
moon fmt --check
moon check --deny-warn --target wasm-gc
moon check --deny-warn --target js
moon test --deny-warn --target wasm-gc
moon test --deny-warn --target js
moon build --release --target wasm-gc
```

Local wasm-gc, wasm and js debug/release suites each pass **67/67 tests**; strict checks also pass native, while this Windows machine lacks a native C compiler. The Linux CI matrix separately verifies actual native builds/tests. Run `python tools/audit_delivery.py --strict` for conservative production LOC and nonempty/unique-tree/author history checks (meaningfulness is reviewed manually).

The repaired implementation was remeasured on 2026-10-14: **60/60 comparisons** (five deterministic fixtures, four metrics, three portable backends) pass the predeclared FFmpeg regression limits. This is **not standards certification**. See [independent validation](docs/validation/README.md), [actual results](docs/validation/reference-results.md) and [batch timings](docs/validation/batch-results.md); throughput includes process startup and PCM generation, not just the DSP loop. No external audio fixtures are included.

Controller and audit tests: `python -m unittest discover -s tools -p "test_*.py" -v`. Optional controllers use only the Python standard library.

## Design and references

See [`docs/design/conformance.md`](docs/design/conformance.md) for the algorithm, bounded-memory tradeoffs, input invariants, and unsupported behavior. See [`docs/competition/duplicate-check.md`](docs/competition/duplicate-check.md) for the recorded, finite-scope ecosystem review.

The design references ITU-R BS.1770-5 and EBU Tech 3341/3342/3343. The fixed Rust `sdroege/ebur128` v0.1.10 commit is an independent comparison/reference pointer; no Rust source was copied or translated. See [`THIRD_PARTY.md`](THIRD_PARTY.md), [`LICENSE`](LICENSE), and [`AI_USAGE.md`](AI_USAGE.md).

## Downstream workflows and interchange

1. **Media ingestion/QC:** a decoder supplies 48 kHz interleaved blocks; analyze each independent asset and retain I/LRA/SP/TP plus gate diagnostics for explicit per-asset policy decisions. The batch example keeps failures even if a pooled result appears acceptable.
2. **Live metering:** feed bounded blocks with `push_view` and read `snapshot()`/chronological history. Values warm up for 400 ms/3 s; a bounded history is not an audio archive. Finishing flushes FIR tails without inventing extra input frames.
3. **Editorial/headroom tools:** analyze mono/stereo/5.0 PCM, inspect channel peaks and derive advisory ceiling-constrained constant gain. Downstream software applies or rejects it and remeasures; fixed-gate predictions are not guaranteed normalized results.

`report.to_json()` produces a detached versioned object for QC integration; unavailable values are explicit `null`. See [JSON contract](docs/design/report-json.md). `LoudnessAggregator::add` and `merge` pool independent-program distributions rather than averaging LUFS or concatenating filter state.

Finite headroom is accepted up to `1e150`, but candidates above +24 LUFS invalidate the corresponding histogram gate instead of clamping. 0.01 LU buckets do not bound near-threshold gate-membership error. Counters cap session length (about 12.43 h mono, 6.21 h stereo, 2.49 h 5.0). See [delivery audit](docs/competition/delivery-audit.md) for verified evidence and pending platform status.
