///|
fn normalization_report() -> @moonloudness.MeasurementReport {
  let analyzer = @moonloudness.Analyzer::new(
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()).unwrap(),
  )
  analyzer
  .push(Array::makei(24000, fn(i) { 0.25 * @math.sin(i.to_double() * 0.13) }))
  .unwrap()
  analyzer.finish()
}

///|
test "normalization peak-limited boost and attenuation expose safe linear gain" {
  let report = normalization_report()
  let lufs = report.integrated_lufs().unwrap()
  let peak = report.true_peak_dbtp().unwrap()
  let boost = report.normalization_plan(lufs + 6.0, peak + 3.0).unwrap()
  assert_eq(boost.peak_constrained(), true)
  assert_eq(boost.applied_gain_db(), 3.0)
  assert_true(
    (boost.linear_gain() - @math.pow(10.0, 3.0 / 20.0)).abs() < 1.0e-12,
  )
  assert_true(
    boost.predicted_true_peak_dbtp() <= boost.true_peak_ceiling_dbtp() + 1.0e-12,
  )
  let attenuate = report.normalization_plan(lufs, peak - 9.0).unwrap()
  assert_eq(attenuate.applied_gain_db(), -9.0)
  assert_true(attenuate.linear_gain() > 0.0 && attenuate.linear_gain() < 1.0)
  assert_true(
    report.true_peak_linear() * attenuate.linear_gain() <=
    @math.pow(10.0, (peak - 9.0) / 20.0) + 1.0e-12,
  )
  let requested = report.normalization_plan(lufs - 6.0, 24.0).unwrap()
  assert_eq(requested.peak_constrained(), false)
  assert_true((requested.applied_gain_db() + 6.0).abs() < 1.0e-12)
  assert_eq(requested.predicted_integrated_lufs(), lufs - 6.0)
  assert_eq(report.integrated_lufs(), Some(lufs))
  assert_eq(report.true_peak_dbtp(), Some(peak))
}

///|
test "normalization invalid inputs boundaries silence and aggregate parity" {
  let report = normalization_report()
  for target in [-70.01, 24.01, 0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    assert_true(
      report.normalization_plan(target, -1.0)
      is Err(@moonloudness.InvalidTargetLufs(_)),
    )
  }
  for ceiling in [-100.01, 24.01, 0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0] {
    assert_true(
      report.normalization_plan(-23.0, ceiling)
      is Err(@moonloudness.InvalidTruePeakCeilingDbtp(_)),
    )
  }
  for target in [-70.0, 24.0] {
    for ceiling in [-100.0, 24.0] {
      let plan = report.normalization_plan(target, ceiling).unwrap()
      assert_true(plan.linear_gain() > 0.0)
      assert_true(plan.predicted_true_peak_dbtp() <= ceiling + 1.0e-12)
    }
  }
  let empty = @moonloudness.Analyzer::new(
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::mono()).unwrap(),
  ).finish()
  assert_true(
    empty.normalization_plan(-23.0, -1.0)
    is Err(@moonloudness.MissingIntegratedLoudness),
  )
  let aggregate = @moonloudness.LoudnessAggregator::new(48000).unwrap()
  assert_true(
    aggregate.finish().normalization_plan(-23.0, -1.0)
    is Err(@moonloudness.MissingIntegratedLoudness),
  )
  assert_true(aggregate.add(report) is Ok(_))
  let single = report.normalization_plan(-23.0, -1.0).unwrap()
  let combined = aggregate.finish().normalization_plan(-23.0, -1.0).unwrap()
  assert_eq(single.linear_gain(), combined.linear_gain())
  assert_eq(single.applied_gain_db(), combined.applied_gain_db())
}
