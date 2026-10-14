///|
fn limits_meter(layout : ChannelLayout) -> Analyzer {
  match MeterConfig::new(48000, layout) {
    Ok(c) => Analyzer::new(c)
    Err(_) => panic()
  }
}

///|
test "sample counter overflow is rejected atomically without allocating long streams" {
  let m = limits_meter(ChannelLayout::stereo())
  m.sample_count = 2147483646
  let before = m.snapshot()
  assert_true(m.push([0.5, -0.5]) is Err(CounterOverflow))
  assert_eq(m.frame_count(), before.frame_count())
  assert_eq(m.sample_count(), before.sample_count())
  assert_eq(m.sample_peak_linear(), 0.0)
  assert_eq(m.history().length(), 0)
  assert_eq(m.integrated_distribution.total_count, 0.0)
  assert_true(m.push([]) is Ok(_))
  m.reset()
  assert_eq(m.sample_count(), 0)
  assert_true(m.push([0.5, -0.5]) is Ok(_))
}

///|
test "frame count boundary permits final frame and safe FIR flushing" {
  let m = limits_meter(ChannelLayout::mono())
  m.frame_count = 2147483646
  m.sample_count = 2147483646
  assert_true(m.push([-0.5]) is Ok(_))
  assert_eq(m.frame_count(), 2147483647)
  assert_eq(m.sample_count(), 2147483647)
  assert_true(m.push([1.0]) is Err(CounterOverflow))
  assert_eq(m.sample_peak_linear(), 0.5)
  assert_eq(m.finish().frame_count(), 2147483647)
  assert_true(m.push([]) is Err(AnalyzerFinished))
}

///|
test "invalid tail samples never partially advance measurement state" {
  for xs in [[0.25, 0.0 / 0.0], [0.25, 1.0 / 0.0], [0.25, 1.0e151]] {
    let m = limits_meter(ChannelLayout::mono())
    assert_true(m.push(xs) is Err(_))
    assert_eq(m.frame_count(), 0)
    assert_eq(m.sample_count(), 0)
    assert_eq(m.sample_peak_linear(), 0.0)
    assert_eq(m.true_peak_linear(), 0.0)
    assert_eq(m.momentary_lufs(), None)
  }
}
