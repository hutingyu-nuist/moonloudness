///|
test "out-of-range loudness is diagnosed through reports aggregation and JSON" {
  let c = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(c) => c
    Err(_) => panic()
  }
  let m = @moonloudness.Analyzer::new(c)
  let xs : Array[Double] = []
  for i in 0..<144000 {
    xs.push(if i % 2 == 0 { 100.0 } else { -100.0 })
  }
  assert_true(m.push(xs) is Ok(_))
  let r = m.finish()
  assert_true(r.integrated_status() is @moonloudness.HistogramRangeExceeded(27))
  assert_true(r.lra_status() is @moonloudness.HistogramRangeExceeded(1))
  assert_eq(r.integrated_lufs(), None)
  assert_eq(r.loudness_range_lu(), None)
  assert_eq(r.sample_peak_linear(), 100.0)
  assert_true(
    r.to_json()
    is {
      "availability": {
        "integrated": {
          "status": "histogram_range_exceeded",
          "above_range_blocks": 27,
          ..
        },
        ..
      },
      ..
    },
  )
  let a = match @moonloudness.LoudnessAggregator::new(48000) {
    Ok(a) => a
    Err(_) => panic()
  }
  assert_true(a.add(r) is Ok(_))
  let b = match @moonloudness.LoudnessAggregator::new(48000) {
    Ok(b) => b
    Err(_) => panic()
  }
  assert_true(b.merge(a) is Ok(_))
  assert_true(
    b.finish().integrated_status() is @moonloudness.HistogramRangeExceeded(27),
  )
  assert_eq(b.finish().integrated_lufs(), None)
  m.reset()
  assert_true(m.integrated_status() is @moonloudness.WarmingUp)
}
