///|
/// Converts unavailable or non-finite quantities to explicit JSON null.
fn report_json_number(value : Double?) -> Json {
  match value {
    Some(number) if number - number == 0.0 => Json::number(number)
    _ => Json::null()
  }
}

///|
fn report_integrated_gate_json(gate : IntegratedGateReport?) -> Json {
  match gate {
    None => Json::null()
    Some(gate) =>
      Json::object({
        "absolute_threshold_lufs": report_json_number(
          Some(gate.absolute_threshold_lufs()),
        ),
        "relative_threshold_lufs": report_json_number(
          Some(gate.relative_threshold_lufs()),
        ),
        "applied_threshold_lufs": report_json_number(
          Some(gate.applied_threshold_lufs()),
        ),
        "candidate_block_count": gate.candidate_block_count().to_json(),
        "gated_block_count": gate.gated_block_count().to_json(),
        "integrated_lufs": report_json_number(Some(gate.integrated_lufs())),
      })
  }
}

///|
fn report_lra_gate_json(gate : LraGateReport?) -> Json {
  match gate {
    None => Json::null()
    Some(gate) =>
      Json::object({
        "absolute_threshold_lufs": report_json_number(
          Some(gate.absolute_threshold_lufs()),
        ),
        "relative_threshold_lufs": report_json_number(
          Some(gate.relative_threshold_lufs()),
        ),
        "applied_threshold_lufs": report_json_number(
          Some(gate.applied_threshold_lufs()),
        ),
        "candidate_block_count": gate.candidate_block_count().to_json(),
        "gated_block_count": gate.gated_block_count().to_json(),
        "percentile_10_lufs": report_json_number(
          Some(gate.percentile_10_lufs()),
        ),
        "percentile_95_lufs": report_json_number(
          Some(gate.percentile_95_lufs()),
        ),
        "loudness_range_lu": report_json_number(Some(gate.loudness_range_lu())),
      })
  }
}

///|
/// Detached machine-readable report, schema "moonloudness.measurement" v1.
/// Keys are inserted in a fixed order, with no timestamps or mutable state.
/// All optional measurements and gates are present: unavailable/non-finite
/// numeric values become null, never NaN/Infinity. Counters are JSON numbers;
/// units are explicit in field names (Hz, seconds, LUFS, LU, dBFS, dBTP).
/// Layout is inferred from the public channel-peak count for the supported
/// mono/stereo/5.0 layouts. Unknown layouts have null names/labels, not a guess.
/// Nested loudness, gates, and peaks preserve the public getters verbatim.
/// Every object/array is newly allocated; editing returned JSON cannot change
/// the report, analyzer, cached report, or later exports.
pub fn MeasurementReport::to_json(self : MeasurementReport) -> Json {
  let channel_peaks = self.channel_sample_peaks_linear()
  let layout : ChannelLayout? = match channel_peaks.length() {
    1 => Some(ChannelLayout::mono())
    2 => Some(ChannelLayout::stereo())
    5 => Some(ChannelLayout::five_point_zero())
    _ => None
  }
  let name : Json = match channel_peaks.length() {
    1 => Json::string("mono")
    2 => Json::string("stereo")
    5 => Json::string("5.0")
    _ => Json::null()
  }
  let labels : Array[Json] = []
  let peaks : Array[Json] = []
  for index in 0..<channel_peaks.length() {
    let label = match layout {
      Some(layout) =>
        match layout.channel_label(index) {
          Some(label) => Json::string(label)
          None => Json::null()
        }
      None => Json::null()
    }
    labels.push(label)
    let peak = channel_peaks[index]
    // Construct separate values so even the two returned label containers own
    // their structure; labels themselves are immutable JSON strings/nulls.
    peaks.push(
      Json::object({
        "label": label,
        "sample_linear": report_json_number(Some(peak)),
        "sample_dbfs": report_json_number(amplitude_to_db(peak)),
      }),
    )
  }
  Json::object({
    "schema": Json::string("moonloudness.measurement"),
    "schema_version": (1).to_json(),
    "sample_rate_hz": self.sample_rate().to_json(),
    "frame_count": self.frame_count().to_json(),
    "duration_seconds": report_json_number(Some(self.duration_seconds())),
    "layout": Json::object({
      "name": name,
      "channel_count": channel_peaks.length().to_json(),
      "channel_labels": Json::array(labels),
    }),
    "loudness": Json::object({
      "integrated_lufs": report_json_number(self.integrated_lufs()),
      "loudness_range_lu": report_json_number(self.loudness_range_lu()),
      "momentary_lufs": report_json_number(self.momentary_lufs()),
      "short_term_lufs": report_json_number(self.short_term_lufs()),
    }),
    "gates": Json::object({
      "integrated": report_integrated_gate_json(self.integrated_gate()),
      "lra": report_lra_gate_json(self.lra_gate()),
    }),
    "peaks": Json::object({
      "sample_linear": report_json_number(Some(self.sample_peak_linear())),
      "sample_dbfs": report_json_number(self.sample_peak_dbfs()),
      "true_linear": report_json_number(Some(self.true_peak_linear())),
      "true_dbtp": report_json_number(self.true_peak_dbtp()),
      "channels": Json::array(peaks),
    }),
  })
}

///|
test "report JSON guards non-finite numeric values" {
  assert_eq(report_json_number(Some(0.0 / 0.0)), Json::null())
  assert_eq(report_json_number(Some(1.0 / 0.0)), Json::null())
  assert_eq(report_json_number(Some(-1.0 / 0.0)), Json::null())
  assert_eq(report_json_number(None), Json::null())
  assert_eq(report_json_number(Some(0.0)), Json::number(0.0))
}
