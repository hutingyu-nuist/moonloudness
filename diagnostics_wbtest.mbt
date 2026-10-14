///|
test "above-range blocks cannot silently produce clamped LRA or integrated loudness" {
  let h = LoudnessHistogram::new()
  h.push_energy(1000.0)
  h.push_energy(10000.0)
  assert_eq(h.status(), HistogramRangeExceeded(2))
  assert_true(integrated_gate_from_histogram(h) is None)
  assert_true(lra_gate_from_histogram(h) is None)
  let copied = h.clone()
  h.clear()
  assert_eq(h.status(), WarmingUp)
  assert_eq(copied.status(), HistogramRangeExceeded(2))
  h.merge(copied)
  assert_eq(h.status(), HistogramRangeExceeded(2))
}

///|
test "gate status distinguishes warming up and silence" {
  let h = LoudnessHistogram::new()
  assert_eq(h.status(), WarmingUp)
  h.push_energy(0.0)
  assert_eq(h.status(), BelowAbsoluteGate)
  h.push_energy(1.0)
  assert_eq(h.status(), Available)
}
