# MoonLoudness

MoonLoudness is a pure MoonBit library for streaming loudness and peak analysis of interleaved PCM. It provides an in-process measurement core for quality-control pipelines, batch media tools, live meters, and audio engineering applications.

## Install

The module has not yet been published to MoonCakes. To inspect and run the source before publication:

```sh
git clone https://github.com/hutingyu-nuist/moonloudness.git
cd moonloudness
moon check --target wasm-gc
moon test --target wasm-gc
```

After the participant publishes the module, downstream MoonBit projects can add it with `moon add hutingyu-nuist/moonloudness`.

## Supported measurement path

- 48,000 Hz PCM samples in interleaved frames; mono (`C`), stereo (`L,R`), and 5.0 (`L,R,C,Ls,Rs`, without LFE).
- Per-channel K-weighting, 400 ms momentary and 3 s short-term windows, integrated loudness gating, short-term loudness range (LRA), sample peaks, and four-phase true-peak estimates.
- Whole-chunk input validation before mutation. Incomplete frames, non-finite values, and magnitudes above `1e150` are rejected.
- Bounded measurement history (600 points by default; configurable from 0 to 100,000) and fixed-memory aggregation of finalized independent program reports.
- Auditable gate thresholds/block counts and a non-destructive constant-gain recommendation constrained by a caller-provided true-peak ceiling.

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

The library package contains **1,654 physical lines** of non-test `.mbt` implementation (count includes blank and documentation lines; excludes test files and `.mbti`). CI also runs native build/tests on Linux. No external audio fixtures are included; tests use deterministic generated signals and numerical boundary assertions.

## Design and references

See [`docs/design/conformance.md`](docs/design/conformance.md) for the algorithm, bounded-memory tradeoffs, input invariants, and unsupported behavior. See [`docs/competition/duplicate-check.md`](docs/competition/duplicate-check.md) for the recorded, finite-scope ecosystem review.

The design references ITU-R BS.1770-5 and EBU Tech 3341/3342/3343. The fixed Rust `sdroege/ebur128` v0.1.10 commit is an independent comparison/reference pointer; no Rust source was copied or translated. See [`THIRD_PARTY.md`](THIRD_PARTY.md), [`LICENSE`](LICENSE), and [`AI_USAGE.md`](AI_USAGE.md).
