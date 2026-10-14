# Independent FFmpeg differential validation

## Repeat

From the module root, with Python 3.8+, MoonBit, its normal JS/Wasm runners,
and an independently installed FFmpeg supporting `ebur128` true peaks:

```sh
python tools/test_validate_reference.py
python tools/validate_reference.py
# Explicit, intentional persistent evidence file (otherwise only stdout):
python tools/validate_reference.py --report docs/validation/reference-results.md
# PATH lookup can be overridden; paths containing spaces are single arguments:
python tools/validate_reference.py --ffmpeg "/path/to/ffmpeg" --moon "/path/to/moon"
```

The default targets are `wasm wasm-gc js`. `--targets js` is a quicker diagnostic,
not evidence for the other targets. Every subprocess is checked and has a 300 s
watchdog. Exit 0 means all comparisons passed; 1 means measured disagreement;
2 means infrastructure, parsing, or fixture parity prevented a complete run.
No networking, binary installation, audio download, FFmpeg source copy, or
redistribution is performed. Build products, generated f64le PCM, and FFmpeg
logs live only in an automatically cleaned OS temporary directory outside the
repository. Set TMP/TEMP/TMPDIR outside the checkout. `--report` is the only
intentional persistent output. The harness needs no third-party Python module.

FFmpeg is an independently run optional test tool, not a library dependency.
Its `ebur128=peak=sample+true` filter consumes explicitly laid-out 48 kHz f64le
PCM; mono dual-mono compensation is not enabled. No WAV encoding, lossy codec,
normalization, downmix, or decoder can obscure a difference. The MoonBit
executable independently synthesizes the same formulas, feeds 997-frame chunks
to the existing public analyzer API, and emits JSON lines for I/LRA/SP/TP.
It does not implement a competing loudness meter.

## Original deterministic fixtures

For frame `n`, use `p = 2*pi*(n % 48)/48` and `pi=3.141592653589793`.
Reducing phase each period avoids accumulating large-angle sine drift.

| ID | Length | Layout | Formula / intended coverage |
|---|---:|---|---|
| steady | 8 s | mono | `0.1*sin(p)`: 1 kHz calibration and zero LRA |
| gated | 40 s | mono | 1 kHz; amplitude 0 for seconds [0,4), .01 [4,12), .1 [12,20), .001 [20,28), .03 [28,36), 0 [36,40): silence, level changes and relative gating |
| stereo | 8 s | L,R | `.1*sin(p), .05*sin(p+pi/2)`: summed energy, not downmixed PCM |
| surround | 8 s | L,R,C,BL,BR (5.0) | only index 3 active, `.1*sin(p)`: library Ls maps to FFmpeg BL, 1.41 energy weight |
| intersample | 8 s | mono | `.8*e(n)*sin(2*pi*(n%4)/4+pi/4)`: 12 kHz with under-reading sample peaks |

For the last fixture, `e(n)=n/4800` for the first 4800 frames,
`(384000-1-n)/4800` for the last 4800, and 1 otherwise. These linear 100 ms
fades suppress edge overshoot rather than disguising a failing peak comparison.
All formulas are original synthetic fixtures, not redistributed EBU test assets.
Both implementations accumulate sample sum and squared energy in frame/channel
order. Counts, these sums, and exact sample peak are checked for parity before
loudness comparison. SHA256 identifies Python's actual f64le bytes. Different
host sine implementations can differ in last bits; parity is not a proof that
every sample is bit-identical.

## Predeclared comparison limits and interpretation

Compare full MoonBit values against FFmpeg's final summary, which displays one
decimal. Add 0.05 for reference rounding to the following absolute engineering
limits (LU for I/LRA, dB for peaks):

- Integrated: 0.15 (+0.05 rounding = 0.20).
- LRA: 0.50 (+0.05 = 0.55).
- Sample peak: 0.01 (+0.05 = 0.06).
- True peak: 0.30 (+0.05 = 0.35).

These were selected before running the comparisons, not fitted afterward.
Integrated allows bounded histogram/gate differences; LRA allows finite
percentile/bin/cadence differences; sample peak should be exact before reference
rounding; TP allows different interpolation implementations. Tolerances are
regression criteria, **not official EBU/ITU certification thresholds**. The
parser deliberately selects the final Summary, handles multichannel peak lists
by maximum, and rejects missing/non-finite reference values for these fixtures.
Tests exercise boundary failures and unusable output; fake parser strings are
unit test inputs, not result evidence.

The library currently implements 48 kHz only, mono/stereo/5.0 only, bounded
loudness histograms, and a four-phase FIR peak estimate. Its source collects
400 ms integrated windows and 3 s LRA windows at a 100 ms cadence; a finite
synthetic set does not establish correctness for all durations, window phases,
near-threshold signals, rates, layouts, transients, music, or codec input. Short
programs and silence-only measurements are not validated here. FFmpeg itself
is a differential comparator, not a certification authority. Do not infer
conformance or broaden limits from a passing table.

## Measured observation (2026-10-14)

`reference-results.md` contains the actual environment, input digests, and all
60 comparisons from the three portable targets. All passed the limits. The
largest integrated difference was 0.0516 LU for the gated case; the largest
sample-peak difference was 0.0485 dB, explained by reference tenths rounding.
The intersample signal yielded SP -4.9485 dBFS versus TP -1.8935 dBTP in MoonBit;
FFmpeg reported -4.9 and -1.9. Surround-only integrated loudness was -21.5114
versus mono -23.0036 (about +1.4922 LU), exercising surround weighting. Stereo
was -22.0345 (about +0.9691 LU over mono), consistent with 1.25 summed energy.
The gated LRA was 20.0 LU in both meters. Small passing differences were not
silently rounded to equality. No algorithm failure was observed on this set.

For a failed future run, inspect the case, input parity and summary parsing
first, then channel mapping, boundary windows, gate thresholds, histogram
quantization and peak interpolation. Keep the original failed results and
report the issue; do not claim agreement by changing thresholds. Main library
files are intentionally not patched by this workflow.

## Portable checks recorded on 2026-10-14

`moon check --target TARGET --deny-warn` and `moon test --target TARGET
--deny-warn` passed for each of `wasm`, `wasm-gc`, and `js`, with build output
redirected by `--target-dir` to an OS temporary directory. Each target ran all
20 existing library tests: 20 passed, 0 failed. The Python harness self-tests
ran 8 tests: all passed. `moon info examples/reference` and
`moon fmt examples/reference` completed; the library interface was unchanged.

## Tool references

- FFmpeg filter documentation: <https://ffmpeg.org/ffmpeg-filters.html#ebur128>
- FFmpeg build-dependent license terms: <https://ffmpeg.org/legal.html>

Only documentation was consulted. No comparator source or fixtures were copied.
