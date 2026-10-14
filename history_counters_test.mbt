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
