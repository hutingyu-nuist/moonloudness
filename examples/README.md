# Examples

Run each standalone example from the module root:

```sh
moon run examples/mono --target wasm-gc
moon run examples/stereo --target wasm-gc
moon run examples/surround --target wasm-gc
```

All examples synthesize deterministic signals in MoonBit, so they need no audio files, host decoder, or network access. They demonstrate different downstream usage patterns; they are not EBU conformance fixtures.
