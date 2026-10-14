///|
fn peak_contract_analyzer(
  layout : @moonloudness.ChannelLayout,
) -> @moonloudness.Analyzer {
  let config = match @moonloudness.MeterConfig::new(48000, layout) {
    Ok(value) => value
    Err(_) => panic()
  }
  @moonloudness.Analyzer::new(config)
}

///|
fn peak_contract_abs(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
/// Direct finite convolution on original PCM, not a ring-buffer simulation.
/// Integer tap numerators over 8192 encode the existing four FIR phases.
/// Missing input before startup and after finish is explicitly zero.
fn peak_contract_reference(
  samples : Array[Double],
  channels : Int,
  finalized : Bool,
) -> Double {
  let phases : Array[Array[Int]] = [
    [14, 90, -161, 272, -487, 1125, 7964, -838, 390, -218, 122, -68],
    [-239, 240, -424, 730, -1364, 3810, 6388, -1641, 832, -477, 271, -155],
    [-155, 271, -477, 832, -1641, 6388, 3810, -1364, 730, -424, 240, -239],
    [-68, 122, -218, 390, -838, 7964, 1125, -487, 272, -161, 90, 14],
  ]
  let frames = samples.length() / channels
  let output_frames = frames + (if finalized { 11 } else { 0 })
  let mut peak = 0.0
  for frame in 0..<output_frames {
    for channel in 0..<channels {
      for phase in phases {
        let mut output = 0.0
        for tap in 0..<12 {
          let source = frame - 11 + tap
          if source >= 0 && source < frames {
            output = output +
              samples[source * channels + channel] *
              phase[tap].to_double() /
              8192.0
          }
        }
        let magnitude = peak_contract_abs(output)
        if magnitude > peak {
          peak = magnitude
        }
      }
    }
  }
  // Live and finalized estimates include the original sample-peak floor.
  for sample in samples {
    let magnitude = peak_contract_abs(sample)
    if magnitude > peak {
      peak = magnitude
    }
  }
  peak
}

///|
fn peak_contract_slice(
  samples : Array[Double],
  start : Int,
  end : Int,
) -> Array[Double] {
  let result : Array[Double] = []
  for index in start..<end {
    result.push(samples[index])
  }
  result
}

///|
test "peak_contract_short_streams_use_full_startup_and_tail_zero_padding" {
  for frames in 0..<25 {
    let samples : Array[Double] = []
    for frame in 0..<frames {
      samples.push((frame * 7 % 9 - 4).to_double() / 8.0)
    }
    let analyzer = peak_contract_analyzer(@moonloudness.ChannelLayout::mono())
    assert_true(analyzer.push(samples) is Ok(_))
    assert_eq(
      analyzer.true_peak_linear(),
      peak_contract_reference(samples, 1, false),
    )
    let report = analyzer.finish()
    assert_eq(
      report.true_peak_linear(),
      peak_contract_reference(samples, 1, true),
    )
    assert_eq(report.frame_count(), frames)
    assert_eq(analyzer.frame_count(), frames)
    assert_eq(analyzer.sample_count(), frames)
  }
  let analyzer = peak_contract_analyzer(@moonloudness.ChannelLayout::mono())
  assert_true(analyzer.push([-0.5, -0.5]) is Ok(_))
  assert_eq(analyzer.finish().true_peak_linear(), 0.6224365234375)
}

///|
test "peak_contract_isolated_impulse_keeps_maximum_original_sample" {
  for position in 0..<25 {
    for amplitude in [0.75, -0.75] {
      let samples : Array[Double] = []
      for frame in 0..<25 {
        samples.push(if frame == position { amplitude } else { 0.0 })
      }
      let analyzer = peak_contract_analyzer(@moonloudness.ChannelLayout::mono())
      assert_true(analyzer.push(samples) is Ok(_))
      let report = analyzer.finish()
      assert_eq(report.sample_peak_linear(), 0.75)
      // All interpolation taps are below unity, so a FIR-only report would
      // under-report this impulse without the original-sample maximum floor.
      assert_eq(report.true_peak_linear(), 0.75)
      assert_eq(
        report.true_peak_linear(),
        peak_contract_reference(samples, 1, true),
      )
    }
  }
}

///|
test "peak_contract_tail_intersample_maximum_matches_direct_convolution" {
  let samples = [-0.5, 0.5, -0.5, 0.5, -0.5, 0.5, 0.5, -0.5, 0.5, -0.5, 0.5]
  let analyzer = peak_contract_analyzer(@moonloudness.ChannelLayout::mono())
  assert_true(analyzer.push(samples) is Ok(_))
  let live = analyzer.true_peak_linear()
  assert_eq(live, peak_contract_reference(samples, 1, false))
  let report = analyzer.finish()
  let expected = peak_contract_reference(samples, 1, true)
  assert_true(expected > live)
  assert_true(expected > 1.0)
  assert_eq(report.true_peak_linear(), expected)
  assert_eq(report.sample_peak_linear(), 0.5)
  assert_eq(report.frame_count(), 11)
  assert_eq(analyzer.sample_count(), 11)
  assert_eq(analyzer.finish().true_peak_linear(), expected)
  assert_eq(analyzer.true_peak_linear(), expected)
}

///|
test "peak_contract_chunks_and_channels_match_direct_convolution_at_each_prefix" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let channels = layout.channels()
    let samples : Array[Double] = []
    for frame in 0..<127 {
      for channel in 0..<channels {
        samples.push(((frame * 13 + channel * 7) % 23 - 11).to_double() / 16.0)
      }
    }
    let contiguous = peak_contract_analyzer(layout)
    assert_true(contiguous.push(samples) is Ok(_))
    let expected = peak_contract_reference(samples, channels, true)
    assert_eq(contiguous.finish().true_peak_linear(), expected)
    // Singleton frames cross every possible ring offset. Other strides cross
    // startup, the 12-tap span, and multiple rollovers with unequal chunks.
    for stride in [1, 2, 5, 11, 12, 13, 31] {
      let partitioned = peak_contract_analyzer(layout)
      let mut start = 0
      while start < 127 {
        let end = if start + stride < 127 { start + stride } else { 127 }
        assert_true(partitioned.push([]) is Ok(_))
        assert_true(
          partitioned.push(
            peak_contract_slice(samples, start * channels, end * channels),
          )
          is Ok(_),
        )
        let prefix = peak_contract_slice(samples, 0, end * channels)
        assert_eq(
          partitioned.true_peak_linear(),
          peak_contract_reference(prefix, channels, false),
        )
        assert_eq(partitioned.frame_count(), end)
        assert_eq(partitioned.sample_count(), end * channels)
        start = end
      }
      let report = partitioned.finish()
      assert_eq(report.true_peak_linear(), expected)
      assert_eq(report.sample_peak_linear(), contiguous.sample_peak_linear())
      assert_eq(
        report.channel_sample_peaks_linear(),
        contiguous.channel_sample_peaks_linear(),
      )
      assert_eq(report.frame_count(), 127)
    }
  }
}

///|
test "peak_contract_leading_and_trailing_explicit_zeros_preserve_final_peak" {
  let samples = [-0.5, -0.5, 0.125, 0.25, -0.125]
  let analyzer = peak_contract_analyzer(@moonloudness.ChannelLayout::mono())
  assert_true(analyzer.push(samples) is Ok(_))
  let expected = analyzer.finish().true_peak_linear()
  for leading in [0, 1, 11, 12, 23] {
    for trailing in [0, 1, 11, 12, 23] {
      let padded : Array[Double] = []
      for _ in 0..<leading {
        padded.push(0.0)
      }
      for sample in samples {
        padded.push(sample)
      }
      for _ in 0..<trailing {
        padded.push(0.0)
      }
      let padded_analyzer = peak_contract_analyzer(
        @moonloudness.ChannelLayout::mono(),
      )
      assert_true(padded_analyzer.push(padded) is Ok(_))
      assert_eq(padded_analyzer.finish().true_peak_linear(), expected)
      assert_eq(expected, peak_contract_reference(padded, 1, true))
    }
  }
}

///|
test "peak_contract_reset_clears_tail_and_cached_report_for_all_layouts" {
  for layout in @moonloudness.ChannelLayout::supported() {
    let channels = layout.channels()
    let analyzer = peak_contract_analyzer(layout)
    let loud : Array[Double] = []
    for frame in 0..<13 {
      for channel in 0..<channels {
        loud.push(if (frame + channel) % 3 == 0 { 2.0 } else { -1.0 })
      }
    }
    assert_true(analyzer.push(loud) is Ok(_))
    let old_report = analyzer.finish()
    let old_peak = old_report.true_peak_linear()
    analyzer.reset()
    assert_eq(analyzer.true_peak_linear(), 0.0)
    assert_eq(analyzer.sample_peak_linear(), 0.0)
    assert_eq(analyzer.frame_count(), 0)
    assert_eq(analyzer.sample_count(), 0)
    let quiet : Array[Double] = []
    for channel in 0..<channels {
      quiet.push((channel + 1).to_double() / 64.0)
    }
    assert_true(analyzer.push(quiet) is Ok(_))
    let report = analyzer.finish()
    assert_eq(
      report.true_peak_linear(),
      peak_contract_reference(quiet, channels, true),
    )
    assert_true(report.true_peak_linear() < old_peak)
    assert_eq(report.frame_count(), 1)
    assert_eq(old_report.true_peak_linear(), old_peak)
    analyzer.reset()
    assert_eq(analyzer.finish().true_peak_linear(), 0.0)
  }
}
