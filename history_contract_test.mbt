///|
fn contract_history_meter(capacity : Int) -> @moonloudness.Analyzer {
  @moonloudness.Analyzer::new_with_history_capacity(
    @moonloudness.MeterConfig::new(48000, @moonloudness.ChannelLayout::stereo()).unwrap(),
    capacity,
  ).unwrap()
}

///|
fn history_frames(analyzer : @moonloudness.Analyzer) -> Array[Int] {
  analyzer.history().map(fn(point) { point.frame_count() })
}

///|
test "history ring wraps chronologically and returned arrays and snapshots are detached" {
  let analyzer = contract_history_meter(2)
  analyzer.push([0.25, -0.5]).unwrap()
  analyzer.push(Array::make(28799 * 2, 0.0)).unwrap()
  assert_eq(history_frames(analyzer), [24000, 28800])
  let retained = analyzer.history()
  let oldest = retained[0]
  let peak_copy = oldest.channel_sample_peaks_linear()
  assert_eq(peak_copy, [0.25, 0.5])
  peak_copy[0] = 999.0
  retained[0] = retained[1]
  retained.clear()
  assert_eq(history_frames(analyzer), [24000, 28800])
  assert_eq(oldest.channel_sample_peaks_linear(), [0.25, 0.5])
  analyzer.push([0.75, -1.0]).unwrap()
  analyzer.push(Array::make(4799 * 2, 0.0)).unwrap()
  assert_eq(history_frames(analyzer), [28800, 33600])
  assert_eq(oldest.frame_count(), 24000)
  assert_eq(oldest.sample_peak_linear(), 0.5)
  assert_eq(oldest.channel_sample_peaks_linear(), [0.25, 0.5])
  assert_eq(analyzer.history()[1].channel_sample_peaks_linear(), [0.75, 1.0])
}

///|
test "finish adds a partial endpoint once without duplicating exact emission boundaries" {
  let analyzer = contract_history_meter(3)
  analyzer.push(Array::make(38399 * 2, 0.0)).unwrap()
  assert_eq(history_frames(analyzer), [24000, 28800, 33600])
  let report = analyzer.finish()
  assert_eq(history_frames(analyzer), [28800, 33600, 38399])
  assert_eq(analyzer.history()[2].sample_count(), 76798)
  assert_eq(analyzer.finish().frame_count(), report.frame_count())
  assert_eq(history_frames(analyzer), [28800, 33600, 38399])
  let exact = contract_history_meter(3)
  exact.push(Array::make(24000 * 2, 0.0)).unwrap()
  assert_eq(history_frames(exact), [19200, 24000])
  let _ = exact.finish()
  let _ = exact.finish()
  assert_eq(history_frames(exact), [19200, 24000])
}

///|
test "clearing history preserves live state and reset detaches old snapshots" {
  let analyzer = contract_history_meter(3)
  analyzer.push([0.25, -0.5]).unwrap()
  analyzer.push(Array::make(23999 * 2, 0.0)).unwrap()
  let before = analyzer.snapshot()
  let old_history = analyzer.history()
  analyzer.clear_history()
  assert_eq(history_frames(analyzer), [])
  assert_eq(analyzer.frame_count(), before.frame_count())
  assert_eq(analyzer.sample_count(), before.sample_count())
  assert_eq(analyzer.sample_peak_linear(), before.sample_peak_linear())
  assert_eq(analyzer.momentary_lufs(), before.momentary_lufs())
  analyzer.push(Array::make(4800 * 2, 0.0)).unwrap()
  assert_eq(history_frames(analyzer), [28800])
  let old_report = analyzer.finish()
  analyzer.reset()
  assert_eq(analyzer.history_capacity(), 3)
  assert_eq(history_frames(analyzer), [])
  assert_eq(analyzer.frame_count(), 0)
  assert_eq(analyzer.sample_count(), 0)
  assert_eq(analyzer.sample_peak_linear(), 0.0)
  assert_eq(analyzer.snapshot().channel_sample_peaks_linear(), [0.0, 0.0])
  assert_eq(before.channel_sample_peaks_linear(), [0.25, 0.5])
  assert_eq(old_history[1].frame_count(), 24000)
  assert_eq(old_report.frame_count(), 28800)
  analyzer.push(Array::make(19200 * 2, 0.0)).unwrap()
  assert_eq(history_frames(analyzer), [19200])
  assert_eq(analyzer.history()[0].sample_peak_linear(), 0.0)
  assert_eq(old_history[0].channel_sample_peaks_linear(), [0.25, 0.5])
}

///|
test "zero history capacity disables retention not measurement finish or reset" {
  let analyzer = contract_history_meter(0)
  analyzer.push(Array::make(24001 * 2, 0.0)).unwrap()
  assert_eq(analyzer.history_capacity(), 0)
  assert_eq(history_frames(analyzer), [])
  assert_eq(analyzer.snapshot().frame_count(), 24001)
  assert_eq(analyzer.snapshot().sample_count(), 48002)
  let report = analyzer.finish()
  assert_eq(report.frame_count(), 24001)
  assert_true(report.momentary_lufs() is Some(_))
  assert_eq(history_frames(analyzer), [])
  analyzer.clear_history()
  analyzer.reset()
  analyzer.push([0.5, -0.25]).unwrap()
  assert_eq(analyzer.finish().sample_peak_linear(), 0.5)
  assert_eq(history_frames(analyzer), [])
}

///|
test "capacity one retains only the newest endpoint and invalid capacity is rejected" {
  let analyzer = contract_history_meter(1)
  analyzer.push(Array::make(28801 * 2, 0.0)).unwrap()
  assert_eq(history_frames(analyzer), [28800])
  let _ = analyzer.finish()
  assert_eq(history_frames(analyzer), [28801])
  let config = @moonloudness.MeterConfig::new(
    48000,
    @moonloudness.ChannelLayout::mono(),
  ).unwrap()
  assert_true(
    @moonloudness.Analyzer::new_with_history_capacity(config, -1)
    is Err(@moonloudness.InvalidHistoryCapacity(-1)),
  )
  assert_true(
    @moonloudness.Analyzer::new_with_history_capacity(config, 100001)
    is Err(@moonloudness.InvalidHistoryCapacity(100001)),
  )
  let empty = contract_history_meter(1)
  let _ = empty.finish()
  assert_eq(history_frames(empty), [])
}
