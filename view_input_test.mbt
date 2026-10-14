///|
test "borrowed views have the same result as copied PCM chunks" {
  let c = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::stereo()) {
    Ok(c) => c
    Err(_) => panic()
  }
  let full = @moonloudness.Analyzer::new(c)
  let sliced = @moonloudness.Analyzer::new(c)
  let xs : Array[Double] = []
  for i in 0..<48000 {
    xs.push((i % 31 - 15).to_double() / 32.0)
  }
  assert_true(full.push(xs) is Ok(_))
  for i in 0..<24 {
    assert_true(sliced.push_view(xs[i * 2000:(i + 1) * 2000]) is Ok(_))
  }
  let a = full.finish()
  let b = sliced.finish()
  assert_eq(a.integrated_lufs(), b.integrated_lufs())
  assert_eq(a.true_peak_linear(), b.true_peak_linear())
  xs[0] = 100.0
  assert_eq(b.sample_peak_linear(), a.sample_peak_linear())
  assert_true(sliced.push_view(xs[:]) is Err(@moonloudness.AnalyzerFinished))
}

///|
test "invalid borrowed view is rejected before mutation" {
  let c = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::stereo()) {
    Ok(c) => c
    Err(_) => panic()
  }
  let m = @moonloudness.Analyzer::new(c)
  let xs = [0.0, 0.0, 1.0e151, 0.0]
  assert_true(
    m.push_view(xs[:]) is Err(@moonloudness.SampleMagnitudeTooLarge(_)),
  )
  assert_eq(m.frame_count(), 0)
  assert_eq(m.sample_peak_linear(), 0.0)
  assert_true(m.push_view(xs[0:3]) is Err(@moonloudness.IncompleteFrame(_, _)))
  assert_eq(m.frame_count(), 0)
}
