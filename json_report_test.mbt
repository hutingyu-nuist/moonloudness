///|
fn report_json_field(value : Json, key : String) -> Json {
  match value {
    Object(fields) => fields.get(key).unwrap()
    _ => panic()
  }
}

///|
fn json_meter(layout : @moonloudness.ChannelLayout) -> @moonloudness.Analyzer {
  @moonloudness.Analyzer::new(
    @moonloudness.MeterConfig::new(48000, layout).unwrap(),
  )
}

///|
test "empty JSON has a versioned explicit null schema and deterministic bytes" {
  let analyzer = json_meter(@moonloudness.ChannelLayout::mono())
  let report = analyzer.finish()
  let first = report.to_json()
  let second = report.to_json()
  assert_eq(first, second)
  assert_eq(first.stringify(), second.stringify())
  assert_eq(@json.parse(first.stringify()), first)
  assert_eq(
    report_json_field(first, "schema"),
    Json::string("moonloudness.measurement"),
  )
  assert_eq(report_json_field(first, "schema_version"), (1).to_json())
  assert_eq(report_json_field(first, "frame_count"), (0).to_json())
  assert_eq(report_json_field(first, "sample_rate_hz"), (48000).to_json())
  assert_eq(report_json_field(first, "duration_seconds"), 0.0.to_json())
  assert_eq(
    report_json_field(first, "loudness"),
    Json::object({
      "integrated_lufs": Json::null(),
      "loudness_range_lu": Json::null(),
      "momentary_lufs": Json::null(),
      "short_term_lufs": Json::null(),
    }),
  )
  assert_eq(
    report_json_field(first, "gates"),
    Json::object({ "integrated": Json::null(), "lra": Json::null() }),
  )
  let peaks = report_json_field(first, "peaks")
  assert_eq(report_json_field(peaks, "sample_linear"), 0.0.to_json())
  assert_eq(report_json_field(peaks, "sample_dbfs"), Json::null())
  assert_eq(report_json_field(peaks, "true_dbtp"), Json::null())
}

///|
test "JSON exposes canonical layouts and channel ordered peaks without aliasing" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let analyzer = json_meter(layout)
    analyzer
    .push(Array::makei(layout.channels(), fn(i) { (i + 1).to_double() / 10.0 }))
    .unwrap()
    let report = analyzer.finish()
    let value = report.to_json()
    let exported_layout = report_json_field(value, "layout")
    assert_eq(
      report_json_field(exported_layout, "channel_count"),
      layout.channels().to_json(),
    )
    let labels = report_json_field(exported_layout, "channel_labels")
    assert_eq(
      labels,
      Json::array(
        Array::makei(layout.channels(), fn(i) {
          layout.channel_label(i).unwrap().to_json()
        }),
      ),
    )
    let channels = report_json_field(
      report_json_field(value, "peaks"),
      "channels",
    )
    match channels {
      Array(channels) => {
        assert_eq(channels.length(), layout.channels())
        for index in 0..<channels.length() {
          assert_eq(
            report_json_field(channels[index], "sample_linear"),
            report.channel_sample_peak_linear(index).unwrap().to_json(),
          )
          assert_eq(
            report_json_field(channels[index], "label"),
            layout.channel_label(index).unwrap().to_json(),
          )
        }
        channels[0] = Json::null()
      }
      _ => panic()
    }
    match value {
      Object(fields) => fields.set("frame_count", (999).to_json())
      _ => panic()
    }
    assert_eq(report.frame_count(), 1)
    assert_eq(analyzer.finish().to_json(), report.to_json())
    assert_eq(report_json_field(report.to_json(), "frame_count"), (1).to_json())
    let saved = report.to_json().stringify()
    analyzer.reset()
    assert_eq(report.to_json().stringify(), saved)
  }
}

///|
test "JSON loudness and full gate trace agree with public getters" {
  let analyzer = json_meter(@moonloudness.ChannelLayout::mono())
  analyzer
  .push(Array::makei(148800, fn(i) { 0.1 * @math.sin(i.to_double() * 0.13) }))
  .unwrap()
  let report = analyzer.finish()
  let value = report.to_json()
  assert_eq(@json.parse(value.stringify()), value)
  assert_eq(
    report_json_field(value, "frame_count"),
    report.frame_count().to_json(),
  )
  let loudness = report_json_field(value, "loudness")
  assert_eq(
    report_json_field(loudness, "integrated_lufs"),
    report.integrated_lufs().unwrap().to_json(),
  )
  assert_eq(
    report_json_field(loudness, "short_term_lufs"),
    report.short_term_lufs().unwrap().to_json(),
  )
  let gates = report_json_field(value, "gates")
  let integrated = report_json_field(gates, "integrated")
  let gate = report.integrated_gate().unwrap()
  assert_eq(
    integrated,
    Json::object({
      "absolute_threshold_lufs": gate.absolute_threshold_lufs().to_json(),
      "relative_threshold_lufs": gate.relative_threshold_lufs().to_json(),
      "applied_threshold_lufs": gate.applied_threshold_lufs().to_json(),
      "candidate_block_count": gate.candidate_block_count().to_json(),
      "gated_block_count": gate.gated_block_count().to_json(),
      "integrated_lufs": gate.integrated_lufs().to_json(),
    }),
  )
  let lra = report_json_field(gates, "lra")
  let range = report.lra_gate().unwrap()
  assert_eq(
    lra,
    Json::object({
      "absolute_threshold_lufs": range.absolute_threshold_lufs().to_json(),
      "relative_threshold_lufs": range.relative_threshold_lufs().to_json(),
      "applied_threshold_lufs": range.applied_threshold_lufs().to_json(),
      "candidate_block_count": range.candidate_block_count().to_json(),
      "gated_block_count": range.gated_block_count().to_json(),
      "percentile_10_lufs": range.percentile_10_lufs().to_json(),
      "percentile_95_lufs": range.percentile_95_lufs().to_json(),
      "loudness_range_lu": range.loudness_range_lu().to_json(),
    }),
  )
  assert_eq(report_json_field(lra, "gated_block_count"), (2).to_json())
}
