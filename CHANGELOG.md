# 更新日志

## 0.1.1 — 2026-10-14

- 将主 README 和示例运行指南改为中文，补全五个示例说明及三类下游集成流程。
- 同步模块简介与版本，明确直方图近似、数值边界、native CI 验证和标准认证限制。
- 测量算法、公共 API 和测试行为保持不变；保留 0.1.0 的发布与验证记录。

## 0.1.0 — 2026-10-14

- Provide streaming 48 kHz mono/stereo/5.0 K-weighting, 400 ms/3 s windows, integrated gating, LRA and sample/four-phase FIR true peaks.
- Include the first complete integrated window; collect candidates every 100 ms.
- Process FIR startup with zero padding, retain the sample-peak floor and flush tail peaks into the final same-time history point.
- Replace subtractive window sums with bounded pairwise sum trees to preserve small energies after large transients.
- Validate complete chunks atomically, update counters per frame, support synchronous zero-copy views and document finite session limits.
- Expose bounded chronological detached history and explicit gate unavailability/range diagnostics.
- Aggregate independent programs and merge validated groups without creating cross-program windows.
- Export detached versioned JSON reports and checked constant-gain recommendations (fixed-gate predictions, not automatic normalization).
- Include mono, stereo, surround, batch-QC and independent-reference workflows, regression tests, reproducible FFmpeg differential comparisons and measured fresh-process throughput.
- Pin compiler/core/action revisions; verify strict checks, release builds, debug/release tests and workflows on four backends in CI.
- Document source provenance, AI assistance, histogram approximation and unsupported rates/layouts; no official conformance claim.
