# Examples

Run each standalone example from the module root:

```sh
moon run examples/mono --target wasm-gc
moon run examples/stereo --target wasm-gc
moon run examples/surround --target wasm-gc
```

All examples synthesize deterministic signals in MoonBit, so they need no audio files, host decoder, or network access. They demonstrate different downstream usage patterns; they are not EBU conformance fixtures.

## Independent reference measurement

```sh
moon run examples/reference --target wasm-gc --release
python tools/test_validate_reference.py
python tools/validate_reference.py
```

The executable emits machine-readable integrated loudness, LRA, sample peak and
true peak for original deterministic fixtures. The Python harness independently
generates matching raw PCM for an installed FFmpeg `ebur128` comparator and
runs all three portable MoonBit targets. No audio assets or comparator binaries
are redistributed. See `docs/validation/README.md` for prerequisites, formulas,
rounding, limits, exit statuses, and actual results. This is not certification.
