///|
fn review_lifecycle_meter(
  layout : @moonloudness.ChannelLayout,
) -> @moonloudness.Analyzer {
  @moonloudness.Analyzer::new_with_history_capacity(
    @moonloudness.MeterConfig::new(48000, layout).unwrap(),
    4,
  ).unwrap()
}

///|
fn review_lifecycle_signal(
  frames : Int,
  channels : Int,
  amplitude : Double,
) -> Array[Double] {
  Array::makei(frames * channels, fn(i) {
    let frame = i / channels
    let channel = i % channels
    amplitude * ((frame * 71 + channel * 17) % 257 - 128).to_double() / 128.0
  })
}

///|
test "review public availability changes at complete window boundaries only" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let channels = layout.channels()
    let meter = review_lifecycle_meter(layout)
    assert_true(meter.integrated_status() is @moonloudness.WarmingUp)
    meter.push(review_lifecycle_signal(19199, channels, 0.1)).unwrap()
    assert_eq(meter.momentary_lufs(), None)
    assert_true(meter.integrated_status() is @moonloudness.WarmingUp)
    meter.push(Array::make(channels, 0.1)).unwrap()
    assert_true(meter.momentary_lufs() is Some(_))
    assert_true(meter.integrated_status() is @moonloudness.Available)
    assert_true(meter.lra_status() is @moonloudness.WarmingUp)
    meter.push(review_lifecycle_signal(124799, channels, 0.1)).unwrap()
    assert_eq(meter.short_term_lufs(), None)
    assert_true(meter.lra_status() is @moonloudness.WarmingUp)
    meter.push(Array::make(channels, 0.1)).unwrap()
    assert_true(meter.short_term_lufs() is Some(_))
    assert_true(meter.lra_status() is @moonloudness.Available)
    let report = meter.finish()
    assert_eq(report.frame_count(), 144000)
    assert_eq(report.integrated_gate().unwrap().candidate_block_count(), 27)
    assert_eq(report.lra_gate().unwrap().candidate_block_count(), 1)
    assert_eq(report.to_json(), meter.finish().to_json())
    let silent = review_lifecycle_meter(layout)
    silent.push(Array::make(144000 * channels, 0.0)).unwrap()
    assert_true(silent.integrated_status() is @moonloudness.BelowAbsoluteGate)
    assert_true(silent.lra_status() is @moonloudness.BelowAbsoluteGate)
    assert_eq(silent.finish().loudness_range_lu(), None)
  }
}

///|
test "review clearing history and reusing analyzer preserve previously exported values" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let meter = review_lifecycle_meter(layout)
    meter.push(review_lifecycle_signal(144000, layout.channels(), 0.1)).unwrap()
    let snapshot = meter.snapshot()
    let snapshot_peak = snapshot.sample_peak_linear()
    let snapshot_channels = snapshot.channel_sample_peaks_linear()
    snapshot_channels[0] = 999.0
    assert_eq(snapshot.channel_sample_peaks_linear()[0], snapshot_peak)
    meter.clear_history()
    assert_eq(meter.history().length(), 0)
    assert_eq(meter.snapshot().frame_count(), snapshot.frame_count())
    assert_eq(meter.snapshot().momentary_lufs(), snapshot.momentary_lufs())
    let first = meter.finish()
    let original_json = first.to_json()
    let exported_channels = first.channel_sample_peaks_linear()
    exported_channels[0] = 999.0
    assert_eq(first.to_json(), original_json)
    assert_eq(meter.history().length(), 1)
    let aggregate = @moonloudness.LoudnessAggregator::new(48000).unwrap()
    aggregate.add(first).unwrap()
    let original_aggregate = aggregate.finish()
    meter.reset()
    meter.push(review_lifecycle_signal(19200, layout.channels(), 0.5)).unwrap()
    assert_eq(meter.finish().frame_count(), 19200)
    assert_eq(first.to_json(), original_json)
    assert_eq(
      aggregate.finish().integrated_lufs(),
      original_aggregate.integrated_lufs(),
    )
    assert_eq(
      aggregate.finish().frame_count(),
      original_aggregate.frame_count(),
    )
    assert_eq(
      aggregate.finish().true_peak_linear(),
      original_aggregate.true_peak_linear(),
    )
    assert_eq(snapshot.frame_count(), 144000)
    assert_eq(snapshot.sample_peak_linear(), snapshot_peak)
  }
}

///|
test "review independent-program grouping and reverse order preserve measurable contracts" {
  let reports : Array[@moonloudness.MeasurementReport] = []
  for layout in @moonloudness.ChannelLayout::supported() {
    for amplitude in [0.03, 0.2] {
      let meter = review_lifecycle_meter(layout)
      meter
      .push(review_lifecycle_signal(144000, layout.channels(), amplitude))
      .unwrap()
      reports.push(meter.finish())
    }
  }
  let direct = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  let reversed = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  let left = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  let right = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  for index in 0..<reports.length() {
    direct.add(reports[index]).unwrap()
    reversed.add(reports[reports.length() - 1 - index]).unwrap()
    if index < 3 {
      left.add(reports[index]).unwrap()
    } else {
      right.add(reports[index]).unwrap()
    }
  }
  let detached = right.finish()
  left.merge(right).unwrap()
  let expected = direct.finish()
  for actual in [left.finish(), reversed.finish()] {
    assert_eq(actual.asset_count(), 6)
    assert_eq(actual.frame_count(), 864000)
    assert_true(
      (actual.integrated_lufs().unwrap() - expected.integrated_lufs().unwrap()).abs() <
      1.0e-10,
    )
    assert_true(
      (actual.loudness_range_lu().unwrap() -
      expected.loudness_range_lu().unwrap()).abs() <
      0.020001,
    )
    assert_eq(actual.sample_peak_linear(), expected.sample_peak_linear())
    assert_eq(actual.true_peak_linear(), expected.true_peak_linear())
    assert_eq(actual.integrated_gate().unwrap().candidate_block_count(), 162)
    assert_eq(actual.lra_gate().unwrap().candidate_block_count(), 6)
  }
  assert_eq(right.finish().integrated_lufs(), detached.integrated_lufs())
  assert_eq(right.finish().loudness_range_lu(), detached.loudness_range_lu())
  assert_eq(right.finish().frame_count(), detached.frame_count())
  assert_eq(right.finish().asset_count(), detached.asset_count())
}
