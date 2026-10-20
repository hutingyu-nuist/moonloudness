///|
fn review_range_meter() -> @moonloudness.Analyzer {
  @moonloudness.Analyzer::new(
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()).unwrap(),
  )
}

///|
fn review_range_pcm(amplitude : Double) -> Array[Double] {
  Array::makei(144000, i => if i % 2 == 0 { amplitude } else { -amplitude })
}

///|
test "review mixed-range stream must not return partial LRA" {
  let meter = review_range_meter()
  assert_true(meter.push(review_range_pcm(100.0)) is Ok(_))
  assert_true(meter.push(review_range_pcm(0.1)) is Ok(_))
  let report = meter.finish()
  assert_true(report.lra_status() is @moonloudness.HistogramRangeExceeded(_))
  assert_true(report.lra_gate() is None)
  assert_eq(report.loudness_range_lu(), None)
  assert_true(
    report.to_json()
    is {
      "loudness": { "loudness_range_lu": Null, .. },
      "gates": { "lra": Null, .. },
      ..
    },
  )
}

///|
test "review mixed-range aggregates suppress LRA after add and merge in both orders" {
  let loud_meter = review_range_meter()
  assert_true(loud_meter.push(review_range_pcm(100.0)) is Ok(_))
  let loud = loud_meter.finish()
  let quiet_meter = review_range_meter()
  assert_true(quiet_meter.push(review_range_pcm(0.1)) is Ok(_))
  let quiet = quiet_meter.finish()
  assert_true(quiet.loudness_range_lu() is Some(_))
  for loud_first in [true, false] {
    let left = @moonloudness.LoudnessAggregator::new(48000).unwrap()
    let right = @moonloudness.LoudnessAggregator::new(48000).unwrap()
    assert_true(left.add(if loud_first { loud } else { quiet }) is Ok(_))
    assert_true(right.add(if loud_first { quiet } else { loud }) is Ok(_))
    assert_true(left.merge(right) is Ok(_))
    let report = left.finish()
    assert_true(report.lra_status() is @moonloudness.HistogramRangeExceeded(1))
    assert_eq(report.loudness_range_lu(), None)
    assert_true(report.lra_gate() is None)
    let sequential = @moonloudness.LoudnessAggregator::new(48000).unwrap()
    assert_true(sequential.add(quiet) is Ok(_))
    assert_true(sequential.add(loud) is Ok(_))
    assert_eq(sequential.finish().loudness_range_lu(), None)
  }
}
