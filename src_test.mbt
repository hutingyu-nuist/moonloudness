///|
/// Creates a deterministic sinusoid without reading external audio assets.
fn mono_tone(
  frames : Int,
  amplitude : Double,
  frequency : Double,
) -> Array[Double] {
  let values : Array[Double] = []
  let pi = 3.141592653589793
  for frame in 0..<frames {
    let angle = 2.0 * pi * frequency * frame.to_double() / 48000.0
    values.push(amplitude * @math.sin(angle))
  }
  values
}

///|
test "configuration_rejects_unimplemented_sample_rates" {
  assert_true(
    match
      @moonloudness.MeterConfig::new(44100, @moonloudness.ChannelLayout::mono()) {
      Err(@moonloudness.UnsupportedSampleRate(44100)) => true
      _ => false
    },
  )
  assert_eq(@moonloudness.ChannelLayout::mono().channels(), 1)
  assert_eq(@moonloudness.ChannelLayout::stereo().channels(), 2)
  assert_eq(@moonloudness.ChannelLayout::five_point_zero().channels(), 5)
}

///|
test "sample_peak_and_atomic_input_validation" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::stereo()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  match analyzer.push([0.25, -1.25]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.sample_peak_linear(), 1.25)
  assert_eq(analyzer.sample_count(), 2)
  match analyzer.push([0.5]) {
    Err(@moonloudness.IncompleteFrame(1, 2)) => ()
    _ => panic()
  }
  assert_eq(analyzer.sample_count(), 2)
}

///|
test "momentary_integrated_and_peak_report_for_one_kilohertz_tone" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  let samples = mono_tone(48000, 0.1, 1000.0)
  match analyzer.push(samples) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let live = match analyzer.momentary_lufs() {
    Some(value) => value
    None => panic()
  }
  assert_true(live > -26.0 && live < -21.0)
  let report = analyzer.finish()
  let integrated = match report.integrated_lufs() {
    Some(value) => value
    None => panic()
  }
  assert_true(integrated > -26.0 && integrated < -21.0)
  assert_eq(report.frame_count(), 48000)
  assert_true(report.sample_peak_linear() > 0.099)
  assert_true(report.true_peak_linear() >= report.sample_peak_linear())
  assert_eq(report.momentary_lufs(), Some(live))
  match analyzer.push([0.0]) {
    Err(@moonloudness.AnalyzerFinished) => ()
    _ => panic()
  }
}

///|
test "chunk_boundaries_do_not_change_report" {
  let config_a = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let config_b = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let samples = mono_tone(24000, 0.2, 997.0)
  let contiguous = @moonloudness.Analyzer::new(config_a)
  match contiguous.push(samples) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let partitioned = @moonloudness.Analyzer::new(config_b)
  let mut offset = 0
  while offset < samples.length() {
    let end = if offset + 1379 < samples.length() {
      offset + 1379
    } else {
      samples.length()
    }
    let chunk : Array[Double] = []
    for index in offset..<end {
      chunk.push(samples[index])
    }
    match partitioned.push(chunk) {
      Ok(_) => ()
      Err(_) => panic()
    }
    offset = end
  }
  let expected = contiguous.finish()
  let actual = partitioned.finish()
  assert_eq(actual.integrated_lufs(), expected.integrated_lufs())
  assert_eq(actual.momentary_lufs(), expected.momentary_lufs())
  assert_eq(actual.true_peak_linear(), expected.true_peak_linear())
  assert_eq(actual.frame_count(), expected.frame_count())
}

///|
test "finish_is_idempotent_and_reset_starts_a_new_stream" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  match analyzer.push([0.5, -0.25, 0.125]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let first = analyzer.finish()
  let second = analyzer.finish()
  assert_eq(first.frame_count(), second.frame_count())
  assert_eq(first.sample_peak_linear(), second.sample_peak_linear())
  analyzer.reset()
  assert_eq(analyzer.sample_count(), 0)
  assert_eq(analyzer.frame_count(), 0)
  assert_eq(analyzer.sample_peak_linear(), 0.0)
  match analyzer.push([0.25]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.sample_peak_linear(), 0.25)
}

///|
test "five_point_zero_surround_has_published_channel_gain" {
  let mono_config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let surround_config = match
    @moonloudness.MeterConfig::new(
      48000,
      @moonloudness.ChannelLayout::five_point_zero(),
    ) {
    Ok(value) => value
    Err(_) => panic()
  }
  let mono = @moonloudness.Analyzer::new(mono_config)
  let surround = @moonloudness.Analyzer::new(surround_config)
  let tone = mono_tone(24000, 0.1, 1000.0)
  let interleaved : Array[Double] = []
  for sample in tone {
    interleaved.push(0.0)
    interleaved.push(0.0)
    interleaved.push(0.0)
    interleaved.push(sample)
    interleaved.push(0.0)
  }
  match mono.push(tone) {
    Ok(_) => ()
    Err(_) => panic()
  }
  match surround.push(interleaved) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let mono_level = match mono.finish().integrated_lufs() {
    Some(value) => value
    None => panic()
  }
  let surround_level = match surround.finish().integrated_lufs() {
    Some(value) => value
    None => panic()
  }
  let difference = surround_level - mono_level
  assert_true(difference > 1.0 && difference < 2.0)
}

///|
test "channel_peaks_are_ordered_copied_and_reset" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::stereo()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  match analyzer.push([0.2, -0.9, -0.7, 0.3]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.channel_sample_peak_linear(0), Some(0.7))
  assert_eq(analyzer.channel_sample_peak_linear(1), Some(0.9))
  assert_eq(analyzer.channel_sample_peak_linear(-1), None)
  let detached = analyzer.channel_sample_peaks_linear()
  detached[0] = 100.0
  assert_eq(analyzer.channel_sample_peak_linear(0), Some(0.7))
  let report = analyzer.finish()
  assert_eq(report.channel_sample_peaks_linear(), [0.7, 0.9])
  analyzer.reset()
  assert_eq(analyzer.channel_sample_peak_linear(1), Some(0.0))
  assert_eq(analyzer.history().length(), 0)
}

///|
test "oversized_finite_samples_are_rejected_before_any_state_changes" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  match analyzer.push([0.1, 1.0e+151]) {
    Err(@moonloudness.SampleMagnitudeTooLarge(_)) => ()
    _ => panic()
  }
  assert_eq(analyzer.sample_count(), 0)
  assert_eq(analyzer.frame_count(), 0)
  assert_eq(analyzer.sample_peak_linear(), 0.0)
  match analyzer.push([0.1]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.sample_count(), 1)
}

///|
test "integrated_gate_begins_with_first_complete_400ms_window" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = match
    @moonloudness.Analyzer::new_with_history_capacity(config, 3) {
    Ok(value) => value
    Err(_) => panic()
  }
  match analyzer.push(mono_tone(19199, 0.1, 1000.0)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.history().length(), 0)
  match analyzer.push([0.0]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.history().length(), 1)
  let first = analyzer.history()[0]
  assert_eq(first.frame_count(), 19200)
  let mut remaining = 19200
  while remaining > 0 {
    let amount = if remaining > 2400 { 2400 } else { remaining }
    match analyzer.push(mono_tone(amount, 0.1, 1000.0)) {
      Ok(_) => ()
      Err(_) => panic()
    }
    remaining = remaining - amount
  }
  assert_eq(analyzer.history().length(), 3)
  let retained = analyzer.history()
  assert_eq(retained[0].frame_count(), 28800)
  assert_eq(retained[1].frame_count(), 33600)
  assert_eq(retained[2].frame_count(), 38400)
  let report = analyzer.finish()
  let gate = match report.integrated_gate() {
    Some(value) => value
    None => panic()
  }
  assert_eq(gate.candidate_block_count(), 5)
  assert_true(gate.gated_block_count() > 0)
  assert_eq(gate.absolute_threshold_lufs(), -70.0)
}

///|
test "history_capacity_zero_disables_retention_but_keeps_live_snapshot" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  assert_true(
    match @moonloudness.Analyzer::new_with_history_capacity(config, -1) {
      Err(@moonloudness.InvalidHistoryCapacity(-1)) => true
      _ => false
    },
  )
  let analyzer = match
    @moonloudness.Analyzer::new_with_history_capacity(config, 0) {
    Ok(value) => value
    Err(_) => panic()
  }
  match analyzer.push(mono_tone(19200, 0.1, 1000.0)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.history_capacity(), 0)
  assert_eq(analyzer.history().length(), 0)
  assert_eq(analyzer.snapshot().frame_count(), 19200)
  assert_true(analyzer.snapshot().momentary_lufs() is Some(_))
}

///|
test "aggregator_combines_complete_blocks_and_keeps_owned_distribution" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let aggregator = match @moonloudness.LoudnessAggregator::new(48000) {
    Ok(value) => value
    Err(_) => panic()
  }
  assert_true(
    match @moonloudness.LoudnessAggregator::new(44100) {
      Err(@moonloudness.UnsupportedAggregateSampleRate(44100)) => true
      _ => false
    },
  )
  let analyzer = @moonloudness.Analyzer::new(config)
  match analyzer.push(mono_tone(48000, 0.1, 1000.0)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let first = analyzer.finish()
  match aggregator.add(first) {
    Ok(_) => ()
    Err(_) => panic()
  }
  analyzer.reset()
  match analyzer.push(mono_tone(48000, 0.1, 1000.0)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  match aggregator.add(analyzer.finish()) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let combined = aggregator.finish()
  assert_eq(combined.sample_rate(), 48000)
  assert_eq(combined.asset_count(), 2)
  assert_eq(combined.frame_count(), 96000)
  assert_true(combined.integrated_lufs() is Some(_))
  assert_true(combined.sample_peak_linear() > 0.099)
  assert_true(combined.true_peak_linear() >= combined.sample_peak_linear())
  let gate = match combined.integrated_gate() {
    Some(value) => value
    None => panic()
  }
  assert_eq(gate.candidate_block_count(), 14)
}

///|
test "layout_labels_and_weights_match_channel_order" {
  let layout = @moonloudness.ChannelLayout::five_point_zero()
  assert_eq(layout.channel_label(0), Some("L"))
  assert_eq(layout.channel_label(1), Some("R"))
  assert_eq(layout.channel_label(2), Some("C"))
  assert_eq(layout.channel_label(3), Some("Ls"))
  assert_eq(layout.channel_label(4), Some("Rs"))
  assert_eq(layout.channel_label(5), None)
  assert_eq(layout.channel_weight(3), Some(1.41))
  assert_eq(layout.channel_weight(-1), None)
  assert_eq(layout.index_of("C"), Some(2))
  assert_eq(layout.index_of("LFE"), None)
}

///|
test "normalization_plan_is_advisory_and_respects_true_peak_ceiling" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = @moonloudness.Analyzer::new(config)
  match analyzer.push(mono_tone(48000, 0.1, 1000.0)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let report = analyzer.finish()
  let unconstrained = match report.normalization_plan(-16.0, -1.0) {
    Ok(value) => value
    Err(_) => panic()
  }
  assert_true(unconstrained.requested_gain_db() > 0.0)
  assert_true(unconstrained.peak_constrained() == false)
  assert_true(unconstrained.predicted_integrated_lufs() > -17.0)
  let constrained = match report.normalization_plan(-16.0, -30.0) {
    Ok(value) => value
    Err(_) => panic()
  }
  assert_true(constrained.peak_constrained())
  assert_true(constrained.applied_gain_db() < constrained.requested_gain_db())
  assert_true(constrained.predicted_true_peak_dbtp() <= -30.0)
  assert_true(
    match report.normalization_plan(25.0, -1.0) {
      Err(@moonloudness.InvalidTargetLufs(25.0)) => true
      _ => false
    },
  )
  assert_true(report.duration_seconds() == 1.0)
}

///|
test "silence_has_no_logarithmic_or_normalization_result" {
  let config = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let report = @moonloudness.Analyzer::new(config).finish()
  assert_eq(report.sample_peak_dbfs(), None)
  assert_eq(report.true_peak_dbtp(), None)
  assert_eq(report.integrated_lufs(), None)
  assert_true(
    match report.normalization_plan(-16.0, -1.0) {
      Err(@moonloudness.MissingIntegratedLoudness) => true
      _ => false
    },
  )
}
