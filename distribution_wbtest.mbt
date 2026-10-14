///|
/// Checks numeric histogram expectations without depending on decimal formatting.
fn distribution_test_near(
  actual : Double,
  expected : Double,
  tolerance : Double,
) -> Bool {
  let delta = if actual >= expected {
    actual - expected
  } else {
    expected - actual
  }
  delta <= tolerance
}

///|
test "histogram_percentiles_round_to_nearest_order_statistic" {
  let histogram = LoudnessHistogram::new()
  histogram.push_energy(1.0)
  histogram.push_energy(2.0)
  histogram.push_energy(4.0)
  let p10 = match histogram.percentile_at_or_above(-10.0, 10) {
    Some(value) => value
    None => panic()
  }
  let p95 = match histogram.percentile_at_or_above(-10.0, 95) {
    Some(value) => value
    None => panic()
  }
  assert_true(distribution_test_near(p10, -0.70, 0.000001))
  // For three observations, round((n - 1) * 0.95) selects the last value.
  assert_true(distribution_test_near(p95, 5.32, 0.000001))
  assert_true(distribution_test_near(p95 - p10, 6.02, 0.000001))
  let highest_source_lufs = energy_to_lufs(4.0)
  assert_true(p95 <= highest_source_lufs)
  assert_true(highest_source_lufs - p95 < 0.01)
}

///|
test "histogram_gate_uses_the_first_bucket_edge_not_below_threshold" {
  let histogram = LoudnessHistogram::new()
  histogram.push_energy(1.0)
  assert_eq(histogram.count_at_or_above(-0.70), 1.0)
  assert_eq(histogram.count_at_or_above(-0.699), 0.0)
  assert_eq(histogram.mean_energy_at_or_above(24.01), None)
}

///|
test "histogram_merge_clone_and_clear_keep_fixed_storage_independent" {
  let first = LoudnessHistogram::new()
  first.push_energy(1.0)
  let copied = first.clone()
  let second = LoudnessHistogram::new()
  second.push_energy(4.0)
  copied.merge(second)
  assert_eq(first.count_at_or_above(-10.0), 1.0)
  assert_eq(copied.count_at_or_above(-10.0), 2.0)
  assert_true(
    match copied.mean_energy_at_or_above(-10.0) {
      Some(value) => distribution_test_near(value, 2.5, 0.000001)
      None => false
    },
  )
  copied.clear()
  assert_eq(copied.count_at_or_above(-10.0), 0.0)
  assert_eq(first.count_at_or_above(-10.0), 1.0)
}
