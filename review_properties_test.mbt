///|
fn review_properties_meter(
  layout : @moonloudness.ChannelLayout,
) -> @moonloudness.Analyzer {
  @moonloudness.Analyzer::new_with_history_capacity(
    @moonloudness.MeterConfig::new(48000, layout).unwrap(),
    3,
  ).unwrap()
}

///|
fn review_properties_pcm(frames : Int, channels : Int) -> Array[Double] {
  Array::makei(frames * channels, fn(i) {
    let frame = i / channels
    let channel = i % channels
    let step = if frame < 80000 { 0.03 } else { 0.1 }
    step * ((frame * 37 + channel * 83) % 1009 - 504).to_double() / 512.0
  })
}

///|
test "review deterministic irregular partitions preserve complete public reports in every layout" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let channels = layout.channels()
    let pcm = review_properties_pcm(156001, channels)
    let whole = review_properties_meter(layout)
    let split = review_properties_meter(layout)
    whole.push(pcm).unwrap()
    let mut frame = 0
    let mut chunk = 1
    while frame < 156001 {
      let length = (chunk * 7919 % 10007 + 1).min(156001 - frame)
      split
      .push_view(pcm[frame * channels:(frame + length) * channels])
      .unwrap()
      split.push_view(pcm[0:0]).unwrap()
      frame = frame + length
      chunk = chunk + 1
    }
    let expected = whole.finish()
    let actual = split.finish()
    assert_eq(actual.to_json(), expected.to_json())
    assert_eq(actual.to_json(), split.finish().to_json())
    assert_eq(split.history().length(), 3)
    for i in 0..<3 {
      let a = whole.history()[i]
      let b = split.history()[i]
      assert_eq(a.frame_count(), b.frame_count())
      assert_eq(a.sample_count(), b.sample_count())
      assert_eq(a.momentary_lufs(), b.momentary_lufs())
      assert_eq(a.short_term_lufs(), b.short_term_lufs())
      assert_eq(a.true_peak_linear(), b.true_peak_linear())
    }
  }
}

///|
test "review rejected tail values cannot poison hidden filters or subsequent windows" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let channels = layout.channels()
    let actual = review_properties_meter(layout)
    let reference = review_properties_meter(layout)
    let prefix = review_properties_pcm(19199, channels)
    actual.push(prefix).unwrap()
    reference.push(prefix).unwrap()
    for invalid in [0.0 / 0.0, 1.0 / 0.0, -1.0 / 0.0, 1.00001e150, -1.00001e150] {
      let bad = Array::make(channels * 7, 0.25)
      bad[bad.length() - 1] = invalid
      assert_true(actual.push_view(bad[:]) is Err(_))
    }
    if channels > 1 {
      assert_true(
        actual.push([0.2]) is Err(@moonloudness.IncompleteFrame(_, _)),
      )
    }
    let tail = review_properties_pcm(136802, channels)
    actual.push(tail).unwrap()
    reference.push(tail).unwrap()
    assert_eq(actual.finish().to_json(), reference.finish().to_json())
    assert_true(actual.push([]) is Err(@moonloudness.AnalyzerFinished))
    actual.reset()
    let fresh = review_properties_meter(layout)
    actual.push(tail).unwrap()
    fresh.push(tail).unwrap()
    assert_eq(actual.finish().to_json(), fresh.finish().to_json())
  }
}

///|
test "review sign gain and channel weighting obey analytic invariants away from gates" {
  let pcm = review_properties_pcm(156001, 1)
  let base = review_properties_meter(@moonloudness.ChannelLayout::mono())
  let scaled = review_properties_meter(@moonloudness.ChannelLayout::mono())
  let surround = review_properties_meter(
    @moonloudness.ChannelLayout::five_point_zero(),
  )
  base.push(pcm).unwrap()
  scaled.push(pcm.map(x => -2.0 * x)).unwrap()
  let rear = Array::makei(pcm.length() * 5, fn(i) {
    if i % 5 == 3 {
      pcm[i / 5]
    } else {
      0.0
    }
  })
  surround.push(rear).unwrap()
  let a = base.finish()
  let b = scaled.finish()
  let c = surround.finish()
  let gain_db = 20.0 * @math.log10(2.0)
  assert_true(
    (b.integrated_lufs().unwrap() - a.integrated_lufs().unwrap() - gain_db).abs() <
    1.0e-9,
  )
  assert_eq(b.sample_peak_linear(), a.sample_peak_linear() * 2.0)
  assert_eq(b.true_peak_linear(), a.true_peak_linear() * 2.0)
  assert_true(
    (b.loudness_range_lu().unwrap() - a.loudness_range_lu().unwrap()).abs() <=
    0.020001,
  )
  assert_true(
    (c.integrated_lufs().unwrap() -
    a.integrated_lufs().unwrap() -
    10.0 * @math.log10(1.41)).abs() <
    1.0e-9,
  )
  assert_eq(c.channel_sample_peak_linear(3), Some(a.sample_peak_linear()))
  for channel in [0, 1, 2, 4] {
    assert_eq(c.channel_sample_peak_linear(channel), Some(0.0))
  }
}

///|
test "review maximum admitted samples stay finite with observable range failure" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let meter = review_properties_meter(layout)
    let samples = Array::makei(19200 * layout.channels(), fn(i) {
      if i / layout.channels() % 2 == 0 {
        1.0e150
      } else {
        -1.0e150
      }
    })
    meter.push(samples).unwrap()
    let report = meter.finish()
    assert_eq(report.sample_peak_linear(), 1.0e150)
    assert_true(report.true_peak_linear() - report.true_peak_linear() == 0.0)
    let momentary = report.momentary_lufs().unwrap()
    assert_true(momentary - momentary == 0.0)
    assert_true(
      report.integrated_status() is @moonloudness.HistogramRangeExceeded(1),
    )
    assert_eq(report.integrated_lufs(), None)
  }
}
