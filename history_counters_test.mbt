///|
fn history_config(
  layout : @moonloudness.ChannelLayout,
) -> @moonloudness.MeterConfig {
  match @moonloudness.MeterConfig::new(48000, layout) {
    Ok(c) => c
    Err(_) => panic()
  }
}

///|
test "history counters are coherent throughout a large push" {
  for
    layout in [
      @moonloudness.ChannelLayout::mono(),
      @moonloudness.ChannelLayout::stereo(),
      @moonloudness.ChannelLayout::five_point_zero(),
    ] {
    let m = @moonloudness.Analyzer::new(history_config(layout))
    let xs : Array[Double] = []
    for _ in 0..<(28800 * layout.channels()) {
      xs.push(0.0)
    }
    assert_true(m.push(xs) is Ok(_))
    let points = m.history()
    assert_eq(points.length(), 3)
    for p in points {
      assert_eq(p.sample_count(), p.frame_count() * layout.channels())
    }
  }
}

///|
test "finish refreshes existing boundary point after peak tail flush" {
  let m = @moonloudness.Analyzer::new(
    history_config(@moonloudness.ChannelLayout::mono()),
  )
  let xs : Array[Double] = []
  for _ in 0..<19189 {
    xs.push(0.0)
  }
  for x in [-0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5] {
    xs.push(x)
  }
  assert_true(m.push(xs) is Ok(_))
  let before = m.history()[0].true_peak_linear()
  let r = m.finish()
  let after = m.history()
  assert_eq(after.length(), 1)
  assert_true(r.true_peak_linear() > before)
  assert_eq(after[0].true_peak_linear(), r.true_peak_linear())
  assert_eq(after[0].frame_count(), r.frame_count())
  let _ = m.finish()
  assert_eq(m.history().length(), 1)
}
