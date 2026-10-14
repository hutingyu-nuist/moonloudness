# Independent-program batch throughput

- UTC run: 2026-10-14T04:39:19.247060+00:00
- Platform: Windows-10-10.0.26100-SP0
- Processor: Intel64 Family 6 Model 183 Stepping 1, GenuineIntel
- Logical CPUs reported by OS: 20
- Python timer/controller: 3.8.5 (tags/v3.8.5:580fbb0, Jul 20 2020, 15:43:08) [MSC v.1926 32 bit (Intel)]
- Moon: `C:\Users\42673\.moon-dev\bin\moon.exe`; `moon 0.1.20260920 (914d7da 2026-09-20) /  / Feature flags enabled: rr_moon_mod,rr_moon_pkg`
- Production and batch source SHA256 (sorted path-NUL/content-NUL, LF normalized): `cef4b7432942437a290f37e5545a073731d1c5b8cdc2d656227338e7f2beca31`
- JS runtime: `C:\Program Files\nodejs\node.exe`; `v24.14.0`
- Wasm runtime: `C:\Users\42673\.moon-dev\bin\moonrun.exe`; `moonrun 0.1.20260920 (914d7da 2026-09-20)`

## Timing definition

Build release artifacts once outside the repository. Launch each artifact directly with Node or moonrun; compilation by moon is excluded. Each invocation measures four fresh independent 8 s programs (32 s audio, 1,536,000 frames, 1,920,000 interleaved channel samples). It includes PCM-block generation, analyzer creation/push/finish (K weighting, gating, LRA, SP, TP), independent-program aggregation, JSON printing, process startup, runtime/JIT initialization and pipe capture. Validation parsing is outside the timer. It is not an isolated DSP-loop benchmark.

1 untimed fresh-process warmup(s) then 5 timed fresh-process launches per target. Warmup warms OS/cache state, not persistent-process JIT. Target order: wasm, wasm-gc, js. No CPU isolation, affinity, frequency control, or guarantees for other machines.

| Target | wall seconds (all timed runs) | median s | min s | max s | frames/s at median | channel samples/s at median | audio seconds / wall second |
|---|---|---:|---:|---:|---:|---:|---:|
| wasm | 0.680741, 0.710404, 0.670313, 0.679139, 0.685603 | 0.680741 | 0.670313 | 0.710404 | 2256364 | 2820456 | 47.01x |
| wasm-gc | 0.424804, 0.433339, 0.428050, 0.432908, 0.436494 | 0.432908 | 0.424804 | 0.436494 | 3548100 | 4435125 | 73.92x |
| js | 0.585602, 0.590765, 0.588549, 0.676218, 0.661100 | 0.590765 | 0.585602 | 0.676218 | 2600019 | 3250024 | 54.17x |

## Verified QC output

Every timed and warmup launch is checked for all four program IDs, frames/channels, finite metrics (except silence), the expected per-program QC decisions, and aggregate counters/max peaks and pooled gate/LRA behavior. These expected failing QC decisions demonstrate policy handling; they are not execution failures. All timed launches also agree in measured values across targets (absolute 1e-8 with Python math.isclose default relative 1e-9).

```json
{"channels": 1, "frames": 384000, "id": "on_target", "integrated": -23.00359945276288, "kind": "program", "loudness_ok": true, "lra": 0, "peak_ok": true, "sp": -20, "tp": -19.993304053112176}
{"channels": 2, "frames": 384000, "id": "quiet_stereo", "integrated": -26.013899409402693, "kind": "program", "loudness_ok": false, "lra": 0, "peak_ok": true, "sp": -26.020599913279625, "tp": -26.0139039663918}
{"channels": 1, "frames": 384000, "id": "hot", "integrated": -3.449127346985948, "kind": "program", "loudness_ok": false, "lra": 0, "peak_ok": false, "sp": -0.44552789422304506, "tp": -0.43883194733522374}
{"channels": 1, "frames": 384000, "id": "silence", "integrated": null, "kind": "program", "loudness_ok": false, "lra": null, "peak_ok": false, "sp": null, "tp": null}
{"assets": 4, "duration": 32, "frames": 1536000, "integrated": -3.449127346985948, "kind": "aggregate", "lra": 22.569999999999993, "sp": -0.44552789422304506, "tp": -0.43883194733522374}
```

The illustrative per-program policy is -23 +/-2 LU integrated and TP <= -1 dBTP. Aggregate I/LRA comes from pooled independent-program distributions, not average LUFS and not a concatenated stream with cross-program windows. An aggregate passing any policy cannot override a failing individual program. No certification, production SLA or real-time scheduling claim.
