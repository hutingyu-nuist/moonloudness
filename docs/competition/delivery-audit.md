# Local engineering and delivery audit — 2026-10-14

This public engineering record contains no application or credentials. It describes verified local readiness and the first actual public CI run. Release and MoonCakes status must still be checked from their public endpoints, not inferred from this file.

## Topic and reuse

Retain MoonLoudness: decoded PCM -> bounded streaming K-weighted windows/gates/LRA/peaks -> diagnostic report, history and independent-program aggregation. Media ingestion/QC, live monitoring and editorial/headroom tools each have complete workflows in README and five runnable examples. The fixed-scope candidate comparisons and adjacent source/API/test review are in duplicate-check.md. Finding: 在已记录检索范围内未发现成熟直接替代. This is not exhaustive or permanent uniqueness.

## Actual local checks

- moon info then moon fmt; generated .mbti changes reviewed for the added APIs. moon fmt --check passes.
- Strict moon check --deny-warn passes wasm-gc, wasm, js and native.
- Each portable target's debug and release suites passes 67/67 tests. Each release build passes. Mono/stereo/surround/batch workflows execute on all three targets; reference executes in the independent differential controller.
- Native build/tests were NOT run successfully locally: this Windows environment lacks the required C compiler. Actual Ubuntu 24.04 CI run [38513156907](https://github.com/hutingyu-nuist/moonloudness/actions/runs/38513156907), commit `a930cabd650f2318475eb348e620fe99cef15004`, supplies the missing native evidence: strict check, release build, debug and release tests (67/67 each) and four downstream examples all pass. All four backend jobs and the independent-reference job passed. This is Linux CI evidence, not a local Windows native run.
- All 32 Python controller/audit tests pass (14 reference/batch tests plus 18 repository-audit tests).
- Five original generated signals compared with FFmpeg 8.1: 60/60 metric comparisons pass declared engineering limits across three targets. source/results/environment/limits are recorded in docs/validation. No official EBU suite, standards certification or music-corpus coverage is claimed.
- Fresh-process throughput: four independent 8 s programs, 1,536,000 frames / 1,920,000 channel samples; five launches per backend. Current wasm-gc median 0.432908 s on Windows, 20 logical CPUs. Includes PCM generation/runtime startup/JSON, excludes compilation; no isolated DSP speed claim.
- Instrumented wasm-gc tests also pass 67/67. moon coverage analyze reports 123 uncovered annotated lines across 14 files, including defensive branches and test/reference helpers. This is not 100% coverage and not a percentage estimate.

## Conservative history review

The original uncommitted implementation was committed once as a coherent baseline, not split mechanically. No history was rewritten. All following commits are nonempty and carry the participant's explicitly chosen local author identity; no shared/global Git identity is used. The committed-source audit reports 1,595 substantive production lines, excluding five inline test blocks, test files, examples, comments, blank lines and generated interfaces; structural punctuation lines count. Automated checks reject empty diffs/repeated trees and report counts/authors. Manual review is still required; a nonempty diff alone does not prove meaningful work.

| Commit | Independent development value |
|---|---|
| 7d4f5d3 | coherent implementation baseline, original tests/examples/provenance/duplication evidence |
| 12842f4 | startup zero-padding FIR regression: prevent short-stream missed peaks |
| 8d54be5 | coherent per-frame counters in retained history |
| 4a9d5cf | refresh final same-time history point after FIR tail flush |
| 28067b7 | explicit above-range gating diagnostics instead of fabricated clamped results |
| 3a6bf7b | live TP sample-peak floor and snapshot consistency |
| b0de276 | bounded pairwise energy sums; large-transient cancellation regression |
| 49749a4 | independent impulse/DC/analytic filter-response validation |
| f267f60 | direct-convolution/channel/startup/tail/chunk peak contracts |
| 142680f | synchronous zero-copy view API with whole-chunk atomicity |
| 3aa9502 | independent-group aggregation merge with defensive validation |
| cc4807e | finite linear-gain conversion; fixed-gate prediction boundary |
| 78fcba2 | detached versioned JSON report and ownership/null semantics |
| 33645ac | chronological history wrap/reset/ownership/capacity contracts |
| 0560529 | propagate diagnostic availability to aggregates/JSON; integration regressions |
| 6093178 | finite session-counter and atomic invalid-input boundaries |
| 7e4bc50 | pinned compiler/core/actions and strict four-backend CI matrix |
| 86b9613 | independently generated FFmpeg differential controller/tests and measured evidence |
| 00de325 | independent-program QC workflow and repeatable real throughput controller/tests |
| d5b69cd | repaired-source remeasurements, JSON API contract, native caveat, reproducible reference CI |
| 112ada1 | conservative committed-source/history audit, lexer and temporary-Git boundary tests |

Additional audit-tool and delivery fixes are reviewed by their actual diffs, not counted to pad this table. The conservative 2026-10-20 review counts the first 19 rows plus `112ada1` as 20 meaningful steps; `d5b69cd` is retained as useful supporting validation, not needed to meet the threshold. Later localization/release bookkeeping is not counted merely because its diff is nonempty.

## Privacy, packaging and identity gates

The Chinese application is maintained outside this repository, checked strictly and manually, and never uploaded automatically. Account selection is explicit hutingyu-nuist for GitHub, module namespace and server-verified MoonCakes. Author attribution is separately checked from public commits after push. Token storage is account-specific DPAPI; operations use a private temporary Moon home and never replace shared login files.

Before first push and Release/publication, run the Skill privacy checker on the working tree, all reachable history and the actual inspected ZIP. Check the file inventory manually, including LICENSE, THIRD_PARTY and AI_USAGE. Package identity is hutingyu-nuist/moonloudness@0.1.0. A packaged ZIP or locally verified workflow is NOT proof of a remote upload, green CI or public consumer installation. Publication requires the same clean tested public commit, real green CI, dual server identities and exact-version public metadata; final results live in the private local verification record.

## Confirmed 0.1.0 delivery and 0.1.1 documentation patch

The completed 0.1.0 delivery is public: [main CI 38513697806](https://github.com/hutingyu-nuist/moonloudness/actions/runs/38513697806), [tag CI 38513976663](https://github.com/hutingyu-nuist/moonloudness/actions/runs/38513976663), [Release v0.1.0](https://github.com/hutingyu-nuist/moonloudness/releases/tag/v0.1.0), and [MoonCakes 0.1.0](https://mooncakes.io/docs/hutingyu-nuist/moonloudness@0.1.0). Both CI runs passed all five jobs at commit `b994a78d9950e9ee54a7e0cf9e3a0156f0c65d80`. Public manifest build status was success, and an isolated credential-free consumer passed strict checks and runs on three portable targets. Public ZIP SHA256: `136be9afc8036b340d3306073410956fc819d95944dbb3598a065d271e495d7d`.

Version 0.1.1 localizes the main README, example guide and module description into Chinese. Measurement code and public interfaces are unchanged. Its own release, CI and registry verification are tracked separately; the earlier evidence does not establish publication of this new version. The original 0.1.0 tag and package are preserved.


## 0.1.2 repair verification — 2026-10-20

This dated supplement does not overwrite the October 14 measurements or pretend the old Release already contains the repair. A mixed in-range/above-range short-term distribution previously returned a partial LRA despite HistogramRangeExceeded. The shared LRA gate now returns unavailable before evaluating an incomplete distribution; single-program, aggregate/merge, order variants and measurement JSON null are covered. Public API is unchanged. Channel sample-peak documentation now clearly distinguishes input sample magnitudes from overall FIR true-peak estimates.

- All four targets passed strict checks, release builds and debug/release suites, 76/76 per suite. Five examples ran on all four targets (20 invocations). Local Windows native execution used an isolated Zig 0.14.1 C compiler; `-D_CRT_RAND_S` exposes the MinGW header declaration required by Moon's unchanged Windows runtime. This is now actual local native evidence, not borrowed old CI evidence.
- All 32 Python controller/audit tests passed. Original synthetic PCM vs separately installed FFmpeg 8.1 again passed 60/60 metric comparisons on wasm/wasm-gc/js. These are declared engineering tolerances, not official EBU/ITU certification or coverage of real music corpora.
- Added whole-public-entry properties for chunk partitions, rejected-input atomicity, analytic gain/channel weighting, maximum finite amplitude, exact window warmup, detached report/history/reset ownership and independent-program grouping/order. New local external consumers passed Chinese quickstart and range/editorial integration contracts on all four targets, without publishing credentials.
- Conservative production count: 1,598 substantive non-test MoonBit lines across 11 files, excluding comments/blanks/tests/examples/generated files. Historical 24 nonempty distinct commits were manually reviewed as at least 20 meaningful steps; the new repair is independently meaningful, without empty commits or rewritten history.
- New measured batch run: 32 audio seconds / 1,536,000 frames, five fresh-process launches per portable backend; wasm-gc median 0.582874 seconds on Windows (20 logical CPUs). Includes PCM generation, analysis, aggregation, JSON, startup/JIT and capture, excludes compilation. Concurrent background workload and uncontrolled scheduling limit comparison; no regression/speedup is inferred against October 14's 0.432908 seconds.
- The original private 0.1.1 application remains unchanged outside this repository. The current 0.1.2 application and full REVIEW evidence remain private local artifacts. No application, contact or credential is bundled. Release/registry/CI status is verified independently against the eventual exact public commit; packaging success alone does not establish delivery.
