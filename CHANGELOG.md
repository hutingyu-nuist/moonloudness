# Changelog

## Unreleased

- Added 48 kHz K-weighted momentary (400 ms), short-term (3 s), integrated-gated loudness, LRA, sample-peak, and four-phase true-peak analysis.
- Corrected integrated candidate timing to include the first complete 400 ms window and then sample at 100 ms intervals.
- Added atomic numeric/counter validation, channel-ordered peak measurements, and canonical 1/2/5.0 channel labels and weights.
- Added bounded chronological snapshots, auditable integrated/LRA gate traces, and fixed-memory aggregation of independent finalized program reports.
- Added non-destructive gain recommendations constrained by an explicit true-peak ceiling.
- Added three runnable synthetic-signal examples and cross-target CI checks.
- Documented 0.01 LU gate-histogram quantization and the non-conformance claim boundary; no official EBU fixture suite is included.
