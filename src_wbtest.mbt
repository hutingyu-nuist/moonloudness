///|
/// Creates mono zero-valued PCM for exact frame-boundary tests.
fn short_term_test_silence(frames : Int) -> Array[Double] {
  let samples : Array[Double] = []
  for _ in 0..<frames {
    samples.push(0.0)
  }
  samples
}

///|
test "lra_short_term_samples_start_at_three_seconds_then_every_100ms" {
  let config = match MeterConfig::new(48000, ChannelLayout::mono()) {
    Ok(value) => value
    Err(_) => panic()
  }
  let analyzer = Analyzer::new(config)

  match analyzer.push(short_term_test_silence(143999)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.frame_count, 143999)
  assert_eq(analyzer.latest_short_energy, None)
  assert_eq(analyzer.short_distribution.total_count, 0.0)

  match analyzer.push([0.0]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.frame_count, 144000)
  assert_eq(analyzer.latest_short_energy, Some(0.0))
  assert_eq(analyzer.short_distribution.total_count, 1.0)

  match analyzer.push(short_term_test_silence(4799)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.frame_count, 148799)
  assert_eq(analyzer.short_distribution.total_count, 1.0)

  match analyzer.push([0.0]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.frame_count, 148800)
  assert_eq(analyzer.latest_short_energy, Some(0.0))
  assert_eq(analyzer.short_distribution.total_count, 2.0)

  match analyzer.push(short_term_test_silence(4799)) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.frame_count, 153599)
  assert_eq(analyzer.short_distribution.total_count, 2.0)

  match analyzer.push([0.0]) {
    Ok(_) => ()
    Err(_) => panic()
  }
  assert_eq(analyzer.frame_count, 153600)
  assert_eq(analyzer.short_distribution.total_count, 3.0)
}
