# Measurement JSON contract (version 1)

MeasurementReport::to_json() returns a detached MoonBit Json object. Each call constructs new arrays/maps; mutation does not change the report or subsequent conversions. A consumer checks schema == "moonloudness.measurement" and schema_version == 1. No deserializer, arbitrary JSON validator, or aggregate JSON schema is promised.

| Field | Meaning |
|---|---|
| sample_rate_hz | 48000 |
| frame_count | accepted PCM frames; FIR tail is not input |
| duration_seconds | frame_count / sample_rate_hz |
| layout.name/channel_count/channel_labels | mono/C; stereo/L,R; 5.0/L,R,C,Ls,Rs |
| loudness.integrated_lufs | absolute/relative-gated integrated value or null |
| loudness.loudness_range_lu | gated 95th minus 10th percentile or null |
| loudness.momentary_lufs/short_term_lufs | latest complete 400 ms/3 s window or null during warmup |
| availability.integrated/lra | status objects; inspect before a QC decision |
| gates.integrated/lra | audit objects or null when unavailable |
| peaks.sample_linear/true_linear | linear peaks; silence is zero |
| peaks.sample_dbfs/true_dbtp | logarithmic peaks or null for zero amplitude |
| peaks.channels | ordered label/sample_linear/sample_dbfs objects, not per-channel true peaks |

An integrated gate object contains absolute_threshold_lufs, relative_threshold_lufs, applied_threshold_lufs, candidate_block_count, gated_block_count and integrated_lufs. An LRA gate uses the same threshold/count fields plus percentile_10_lufs, percentile_95_lufs and loudness_range_lu. Candidate counts include below-absolute-gate windows; gated counts describe the final gate.

Statuses distinguish insufficient complete windows, below-absolute-gate candidates, available results and unsupported above-range histogram candidates. See diagnostics.mbt for exact status spellings. JSON null is not loudness zero and must not count as a passing policy result. Completed zero-energy window loudness retains the library's -1000 LUFS sentinel; it is not a physically finite measurement of silence. Gate statuses and nullable integrated/peak values expose the difference.

Non-finite serialization values become null defensively. The schema contains no PCM, private identity, filenames or filesystem metadata. It does not encode recommendations, retained history or aggregation state. Unknown schema versions must not be silently interpreted as version 1. Key ordering is not part of the contract.

Coverage: json_report_test.mbt, range_report_test.mbt, inline non-finite tests and availability diagnostics cover silence/warmup, gates, channel order, detached ownership, reset stability and above-range state.
