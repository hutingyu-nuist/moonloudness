# Measurement behavior and conformance boundary

MoonLoudness is a streaming PCM measurement library. This document describes the shipped behavior, not a claim of full standards conformance. The EBU official test suite has not been run.

## Input and channel model

- Sample rate: exactly 48,000 Hz; the exposed K-weighting coefficient set is for this rate.
- Channel layouts: mono `C`, stereo `L,R`, and 5.0 `L,R,C,Ls,Rs`. Surround channels use the 1.41 loudness multiplier. No LFE channel is accepted.
- `Analyzer::push` takes a complete chunk of interleaved `Array[Double]` frames. Frame shape, finite values, numeric magnitude, and counter capacity are checked before any analyzer mutation.
- Finite headroom samples beyond `[-1,1]` are retained through absolute magnitude `1e150`; larger values are rejected to keep filter/energy arithmetic finite. The analyzer does not clip, normalize, or modify input samples.
- `finish` flushes the FIR delay line and is idempotent. `reset` reuses the same configuration and clears measurement/history state.

## Measurement path

1. Each channel has independent state for the 48 kHz K-weighting shelf and RLB high-pass biquads.
2. Per-frame weighted squared energies feed fixed rolling windows: 19,200 frames (400 ms) for momentary loudness and 144,000 frames (3 s) for short-term loudness.
3. Integrated-loudness candidates are sampled every 4,800 frames beginning at the first complete 400 ms window. Short-term LRA candidates are sampled every 4,800 frames beginning at 3 s.
4. Integrated loudness applies a -70 LUFS absolute gate and a relative gate 10 LU below the absolute-gated mean. LRA applies a -70 LUFS absolute gate and a relative gate 20 LU below its absolute-gated mean, then reports the 10th-to-95th percentile range.
5. Sample peak tracks the largest absolute input sample overall and per channel. True peak uses the 12-tap, four-phase FIR coefficients published in ITU-R BS.1770-5 Annex 2 and flushes the tail on `finish`.

## Bounded storage and quantization

Rolling windows use fixed arrays. Integrated and short-term candidate energies are accumulated into fixed histograms covering -120 to +24 LUFS at 0.01 LU bucket width; memory use therefore does not grow with program duration. The gate lookup rounds a threshold upward to a bucket edge, while percentiles are reported at bucket edges. This is an explicit approximation, bounded by histogram resolution; it is not equivalent to retaining every original block for exact arbitrary-threshold comparisons.

The default history retains 600 points, with one point per 100 ms after the first complete momentary window. Callers may choose 0 to 100,000 points. `history()` returns a detached chronological array; `snapshot()` provides current values without retaining another point. `LoudnessAggregator` merges the bounded candidate histograms from finalized reports, so independent programs can be summarized without concatenating PCM or retaining every report. Rolling-window/filter state is never joined across those program boundaries.

## Gain recommendation

`normalization_plan` is an informational constant-gain calculation based on integrated loudness and true peak. A supplied true-peak ceiling may constrain the suggested gain. The library does not apply gain and does not implement a limiter; downstream systems must decide whether the recommendation is suitable for their delivery profile.

## Unsupported behavior

No decoder, WAV/OGG/container I/O, sample-rate conversion, generic channel masks, 5.1/LFE, playback, encoding, dynamic-range compression, limiting, loudness normalization, editing UI, fingerprinting, or external FFmpeg invocation is included. Inputs must already be decoded and mapped to one of the documented layouts.

## Validation

Tests use deterministic synthetic signals and cover input atomicity, window timing, chunk partition invariance, channel weights/peaks, report finalization/reset, history bounds, aggregation, silence, and peak-constrained gain advice. They do not include licensed EBU fixtures or claim an official conformance pass.

At the current implementation snapshot, the library package has 1,654 physical non-test `.mbt` lines, including blank and documentation lines. The documented count excludes tests, examples, generated interfaces, and build output.

## Histogram range diagnostics

Finite PCM outside full scale remains valid for peak/headroom analysis, but the bounded loudness histogram represents candidates only up to +24 LUFS. Any candidate above this range invalidates the corresponding integrated or LRA gate for the program (and any aggregate containing it), rather than silently clamping the reported percentiles. GateStatus distinguishes warming-up, below-absolute-gate, available, and HistogramRangeExceeded(block_count). Momentary/short-term values and peaks remain available; reset clears the diagnostic. The 0.01 LU bucket resolution applies only to in-range candidates and percentile locations; it does not bound the error introduced by near-threshold gate membership.
