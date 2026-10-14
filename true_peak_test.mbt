///|
/// Returns the mono configuration used to isolate the FIR delay-line behavior.
fn true_peak_test_mono_config() -> @moonloudness.MeterConfig {
  match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(config) => config
    Err(_) => panic()
  }
}

///|
/// Builds an 11-frame suffix whose signs align with one FIR phase's taps.
/// The FIR response becomes observable only after finish() appends its first zero.
fn true_peak_test_tail_pattern() -> Array[Double] {
  [-0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5]
}

///|
test "true_peak_fir_tail_flush_is_chunk_boundary_independent" {
  let samples = true_peak_test_tail_pattern()
  let contiguous = @moonloudness.Analyzer::new(true_peak_test_mono_config())
  match contiguous.push(samples) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_true(contiguous.true_peak_linear() >= 0.5)

  let partitioned = @moonloudness.Analyzer::new(true_peak_test_mono_config())
  let mut start = 0
  for end in [1, 5, 7, 11] {
    let chunk : Array[Double] = []
    for index in start..<end {
      chunk.push(samples[index])
    }
    match partitioned.push(chunk) {
      Ok(_) => ()
      Err(_) => panic()
    }
    start = end
  }
  assert_true(partitioned.true_peak_linear() >= 0.5)

  let contiguous_report = contiguous.finish()
  let partitioned_report = partitioned.finish()
  assert_eq(
    partitioned_report.true_peak_linear(),
    contiguous_report.true_peak_linear(),
  )
  assert_eq(contiguous_report.frame_count(), samples.length())
  assert_eq(contiguous_report.sample_peak_linear(), 0.5)
  assert_true(contiguous_report.true_peak_linear() > 1.0)
}

///|
test "true_peak_reset_clears_previous_stream_peak" {
  let analyzer = @moonloudness.Analyzer::new(true_peak_test_mono_config())
  match analyzer.push(true_peak_test_tail_pattern()) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let first_report = analyzer.finish()
  assert_true(first_report.true_peak_linear() > 1.0)

  analyzer.reset()
  assert_eq(analyzer.true_peak_linear(), 0.0)
  match analyzer.push([0.125]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  let reset_report = analyzer.finish()
  assert_eq(reset_report.sample_peak_linear(), 0.125)
  assert_eq(reset_report.true_peak_linear(), 0.125)
}

///|
test "startup FIR peaks agree with leading zero padding" {
  let a = @moonloudness.Analyzer::new(true_peak_test_mono_config())
  let b = @moonloudness.Analyzer::new(true_peak_test_mono_config())
  assert_true(a.push([-0.5, -0.5]) is Ok(_))
  assert_true(
    b.push([0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -0.5, -0.5])
    is Ok(_),
  )
  let peak = a.finish().true_peak_linear()
  assert_eq(peak, b.finish().true_peak_linear())
  assert_eq(peak, 0.6224365234375)
}
