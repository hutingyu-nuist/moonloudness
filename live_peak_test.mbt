///|
test "live true peak includes input sample peaks before the delayed FIR settles" {
  let c = match
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()) {
    Ok(c) => c
    Err(_) => panic()
  }
  let m = @moonloudness.Analyzer::new(c)
  for x in [0.1, -0.8, 0.4, 0.99] {
    assert_true(m.push([x]) is Ok(_))
    assert_true(m.true_peak_linear() >= m.sample_peak_linear())
    assert_eq(m.snapshot().true_peak_linear(), m.true_peak_linear())
  }
  assert_true(m.finish().true_peak_linear() >= m.true_peak_linear())
}
