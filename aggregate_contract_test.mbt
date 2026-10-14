///|
fn aggregate_meter(
  frames : Int,
  amplitude : Double,
) -> @moonloudness.MeasurementReport {
  let analyzer = @moonloudness.Analyzer::new(
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()).unwrap(),
  )
  let pcm = Array::makei(frames, fn(i) {
    amplitude * @math.sin(i.to_double() * 0.13)
  })
  analyzer.push(pcm).unwrap()
  analyzer.finish()
}

///|
test "independent sub-window programs do not fabricate concatenated blocks" {
  let aggregate = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  assert_true(
    @moonloudness.LoudnessAggregator::new(44100)
    is Err(@moonloudness.UnsupportedAggregateSampleRate(44100)),
  )
  assert_true(aggregate.add(aggregate_meter(10000, 0.25)) is Ok(_))
  assert_true(aggregate.add(aggregate_meter(10000, 0.5)) is Ok(_))
  let report = aggregate.finish()
  assert_eq(report.frame_count(), 20000)
  assert_eq(report.asset_count(), 2)
  assert_eq(report.integrated_lufs(), None)
  assert_true(report.integrated_gate() is None)
  assert_true(aggregate_meter(20000, 0.25).integrated_lufs() is Some(_))
  assert_true(report.sample_peak_linear() > 0.49)
}

///|
test "merge is associative for counts gates and peaks and detached from source" {
  let a = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  let b = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  let c = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  assert_true(a.add(aggregate_meter(19200, 0.1)) is Ok(_))
  assert_true(b.add(aggregate_meter(19200, 0.2)) is Ok(_))
  assert_true(c.add(aggregate_meter(19200, 0.3)) is Ok(_))
  let left = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  let right = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  let bc = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  assert_true(left.merge(a) is Ok(_))
  assert_true(left.merge(b) is Ok(_))
  assert_true(left.merge(c) is Ok(_))
  assert_true(bc.merge(b) is Ok(_))
  assert_true(bc.merge(c) is Ok(_))
  assert_true(right.merge(a) is Ok(_))
  assert_true(right.merge(bc) is Ok(_))
  let l = left.finish()
  let r = right.finish()
  assert_eq(l.frame_count(), r.frame_count())
  assert_eq(l.asset_count(), r.asset_count())
  assert_eq(l.integrated_lufs(), r.integrated_lufs())
  assert_eq(l.sample_peak_linear(), r.sample_peak_linear())
  assert_eq(l.true_peak_linear(), r.true_peak_linear())
  assert_eq(l.integrated_gate().unwrap().gated_block_count(), 3)
  assert_true(bc.merge(bc) is Ok(_))
  assert_eq(right.asset_count(), 3)
  assert_eq(r.asset_count(), 3)
}

///|
test "self merge reaches frame and asset overflow without losing accepted state" {
  let frames = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  assert_true(frames.add(aggregate_meter(1, 0.5)) is Ok(_))
  for _ in 0..<30 {
    assert_true(frames.merge(frames) is Ok(_))
  }
  let before = frames.finish()
  assert_true(
    frames.merge(frames) is Err(@moonloudness.AggregateCounterOverflow),
  )
  assert_eq(frames.frame_count(), 1073741824)
  assert_eq(frames.finish().true_peak_linear(), before.true_peak_linear())
  let assets = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  assert_true(assets.add(aggregate_meter(0, 0.0)) is Ok(_))
  for _ in 0..<30 {
    assert_true(assets.merge(assets) is Ok(_))
  }
  assert_true(
    assets.merge(assets) is Err(@moonloudness.AggregateCounterOverflow),
  )
  assert_eq(assets.asset_count(), 1073741824)
  assert_eq(assets.frame_count(), 0)
}
