# FFmpeg ebur128 differential measurement

- UTC run: 2026-10-14T04:17:20.300774+00:00
- Platform: Windows-10-10.0.26100-SP0
- Python: 3.8.5 (tags/v3.8.5:580fbb0, Jul 20 2020, 15:43:08) [MSC v.1926 32 bit (Intel)]
- Moon executable: `C:\Users\42673\.moon-dev\bin\moon.exe`
- Moon version: `moon 0.1.20260920 (914d7da 2026-09-20) /  / Feature flags enabled: rr_moon_mod,rr_moon_pkg`
- FFmpeg executable: `C:\Users\42673\AppData\Local\Microsoft\WinGet\Packages\Gyan.FFmpeg_Microsoft.Winget.Source_8wekyb3d8bbwe\ffmpeg-8.1-full_build\bin\ffmpeg.exe`
- FFmpeg version: `ffmpeg version 8.1-full_build-www.gyan.dev Copyright (c) 2000-2026 the FFmpeg developers`
- Mode: release; all scratch files/build products in an OS TemporaryDirectory (deleted on exit).
- Input: independently synthesized IEEE float64 little-endian PCM, 48 kHz; no decoder/downmix.
- FFmpeg: `-nostdin -hide_banner -nostats -loglevel info -threads 1 -f f64le -ar 48000 -ch_layout LAYOUT -i PCM -af ebur128=peak=sample+true -f null -`

Limits are engineering regression limits, not certified conformance. Absolute deltas use unrounded MoonBit values and FFmpeg summary tenths. Add 0.05 for FFmpeg rounding to the predeclared limits I=0.15 LU, LRA=0.50 LU, SP=0.01 dB, TP=0.30 dB. Table display rounds to 4 decimals only.

| Target | Case | Metric | MoonBit | FFmpeg | absolute delta | allowed | Result |
|---|---|---|---:|---:|---:|---:|---|
| wasm | steady | integrated | -23.0036 | -23.0000 | 0.0036 | 0.20 | PASS |
| wasm | steady | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm | steady | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm | steady | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm | gated | integrated | -25.7484 | -25.8000 | 0.0516 | 0.20 | PASS |
| wasm | gated | lra | 20.0000 | 20.0000 | 0.0000 | 0.55 | PASS |
| wasm | gated | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm | gated | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm | stereo | integrated | -22.0345 | -22.0000 | 0.0345 | 0.20 | PASS |
| wasm | stereo | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm | stereo | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm | stereo | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm | surround | integrated | -21.5114 | -21.5000 | 0.0114 | 0.20 | PASS |
| wasm | surround | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm | surround | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm | surround | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm | intersample | integrated | -1.6157 | -1.6000 | 0.0157 | 0.20 | PASS |
| wasm | intersample | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm | intersample | sp | -4.9485 | -4.9000 | 0.0485 | 0.06 | PASS |
| wasm | intersample | tp | -1.8935 | -1.9000 | 0.0065 | 0.35 | PASS |
| wasm-gc | steady | integrated | -23.0036 | -23.0000 | 0.0036 | 0.20 | PASS |
| wasm-gc | steady | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm-gc | steady | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm-gc | steady | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm-gc | gated | integrated | -25.7484 | -25.8000 | 0.0516 | 0.20 | PASS |
| wasm-gc | gated | lra | 20.0000 | 20.0000 | 0.0000 | 0.55 | PASS |
| wasm-gc | gated | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm-gc | gated | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm-gc | stereo | integrated | -22.0345 | -22.0000 | 0.0345 | 0.20 | PASS |
| wasm-gc | stereo | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm-gc | stereo | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm-gc | stereo | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm-gc | surround | integrated | -21.5114 | -21.5000 | 0.0114 | 0.20 | PASS |
| wasm-gc | surround | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm-gc | surround | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| wasm-gc | surround | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| wasm-gc | intersample | integrated | -1.6157 | -1.6000 | 0.0157 | 0.20 | PASS |
| wasm-gc | intersample | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| wasm-gc | intersample | sp | -4.9485 | -4.9000 | 0.0485 | 0.06 | PASS |
| wasm-gc | intersample | tp | -1.8935 | -1.9000 | 0.0065 | 0.35 | PASS |
| js | steady | integrated | -23.0036 | -23.0000 | 0.0036 | 0.20 | PASS |
| js | steady | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| js | steady | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| js | steady | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| js | gated | integrated | -25.7484 | -25.8000 | 0.0516 | 0.20 | PASS |
| js | gated | lra | 20.0000 | 20.0000 | 0.0000 | 0.55 | PASS |
| js | gated | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| js | gated | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| js | stereo | integrated | -22.0345 | -22.0000 | 0.0345 | 0.20 | PASS |
| js | stereo | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| js | stereo | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| js | stereo | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| js | surround | integrated | -21.5114 | -21.5000 | 0.0114 | 0.20 | PASS |
| js | surround | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| js | surround | sp | -20.0000 | -20.0000 | 0.0000 | 0.06 | PASS |
| js | surround | tp | -19.9933 | -20.0000 | 0.0067 | 0.35 | PASS |
| js | intersample | integrated | -1.6157 | -1.6000 | 0.0157 | 0.20 | PASS |
| js | intersample | lra | 0.0000 | 0.0000 | 0.0000 | 0.55 | PASS |
| js | intersample | sp | -4.9485 | -4.9000 | 0.0485 | 0.06 | PASS |
| js | intersample | tp | -1.8935 | -1.9000 | 0.0065 | 0.35 | PASS |

## Fixture provenance and parity

Formulas are maintained in `examples/reference/main.mbt` and independently in `tools/validate_reference.py`. Every target checks frame/channel counts, sample sum, squared-energy sum (1e-10 relative, 1e-9 absolute), and sample peak (1e-9 dB) before meter comparisons. This is a drift guard, not a proof of bit-identical PCM.

| Case | seconds | channels/layout | SHA256 of Python f64le input |
|---|---:|---|---|
| steady | 8 | 1 / mono | `0c3ad1cc54adfcc91c1455a0df60c83135646042a48865e83ba30f5a973b9a43` |
| gated | 40 | 1 / mono | `d9f56df9fc7ba5ace4951e3ad1fb3c9702c951ae0aedae7100b3b3709aa05e44` |
| stereo | 8 | 2 / stereo | `810305d3061c735b6e2f336b21f1ba3322b2641e1b022aa2ec731acc0be83fe0` |
| surround | 8 | 5 / 5.0 | `229b8ed4519b3f5acd827cf59fb94e9794c903d87eae8523766173b3a5381cca` |
| intersample | 8 | 1 / mono | `24fe9c5cabd6e4635524b6722c1bc1b9f06761b1403b6fb1f8947ad837a8289e` |

## Outcome

60 metric comparisons; 0 outside limits.

Agreement on these generated cases does not establish full EBU/ITU compliance or certification.
